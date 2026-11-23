import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rental.dart';
import '../services/owner_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O5 Start rental, connected to the database. Opened by O3b after the owner
/// scans a customer's booking QR (or types the booking code).
///
/// Shows the order, lets the owner confirm a counter payment (cash / Touch 'n Go /
/// bank QR), check the IC and vehicle condition, then start the rental.
/// The customer's phone updates by itself and opens the active rental screen.
class StartRentalLiveScreen extends StatefulWidget {
  final String rentalId; // rentals.id
  const StartRentalLiveScreen({super.key, required this.rentalId});

  @override
  State<StartRentalLiveScreen> createState() => _StartRentalLiveScreenState();
}

class _StartRentalLiveScreenState extends State<StartRentalLiveScreen> {
  // Chip labels and the matching value saved in payments.payment_method.
  static const _payLabels = ['Cash', 'Touch ’n Go', 'Bank QR'];
  static const _payValues = ['Cash', 'TnG', 'Bank QR'];

  Map<String, dynamic>? _d;
  String? _error;
  bool _loading = true;

  bool _paid = false;
  bool _icMatches = false;
  bool _triedStart = false;
  bool _busy = false;
  int _payment = 0; // Cash by default
  VehicleCondition _condition = VehicleCondition.good;

  bool get _canStart => _paid && _icMatches;

  List<String> get _missing => [
        if (!_paid) 'Confirm payment to start',
        if (!_icMatches) 'Tick the IC check to start',
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await OwnerApi.fetchDetails(widget.rentalId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _paid = d['status'] != 'pending_payment';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _conditionDb(VehicleCondition c) {
    final n = c.name.toLowerCase();
    if (n.contains('minor')) return 'Minor issue';
    if (n.contains('damag')) return 'Damaged';
    return 'Good';
  }

  String _total(Map<String, dynamic> d) =>
      formatRM((d['total_amount'] as num).toDouble());

  Future<void> _confirmPayment(Map<String, dynamic> d) async {
    setState(() => _busy = true);
    try {
      await OwnerApi.confirmPayment(widget.rentalId, _payValues[_payment]);
      if (!mounted) return;
      setState(() => _paid = true);
      showTopNotice(context,
          title: 'Payment of ${_total(d)} recorded', type: NoticeType.success);
    } on PostgrestException catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't record the payment",
            lines: [e.message],
            type: NoticeType.error);
      }
    } catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't record the payment",
            lines: ['$e'],
            type: NoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewIc(Map<String, dynamic> d) async {
    final u = d['users'] as Map?;
    try {
      final front = await OwnerApi.downloadIc(u?['ic_front_path']);
      final back = await OwnerApi.downloadIc(u?['ic_back_path']);
      if (!mounted) return;
      if (front == null && back == null) {
        showTopNotice(context,
            title: 'No IC photo on file', type: NoticeType.error);
        return;
      }
      showIcViewer(context, (u?['full_name'] ?? 'Customer').toString(),
          front: front, back: back);
    } catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't open the IC",
            lines: ['$e'],
            type: NoticeType.error);
      }
    }
  }

  void _onStartPressed() {
    setState(() => _triedStart = true);
    showTopNotice(context,
        title: "Can't start rental yet",
        lines: _missing,
        type: NoticeType.error);
  }

  Future<void> _startRental(String vehicleName) async {
    setState(() => _busy = true);
    try {
      await OwnerApi.startRental(widget.rentalId, _conditionDb(_condition));
      if (!mounted) return;
      showTopNotice(context,
          title: '$vehicleName rental started', type: NoticeType.success);
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't start the rental",
            lines: [e.message],
            type: NoticeType.error);
      }
    } catch (e) {
      if (mounted) {
        showTopNotice(context,
            title: "Couldn't start the rental",
            lines: ['$e'],
            type: NoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: const AppHeader(title: 'Start rental'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load this booking.\n$_error',
                            textAlign: TextAlign.center,
                            style: inter(14, color: AppColors.text2)),
                      ),
                      TextButton(
                          onPressed: _load, child: const Text('Try again')),
                    ],
                  ),
                )
              : _content(d),
    );
  }

  Widget _content(Map<String, dynamic> d) {
    final v = d['vehicles'] as Map?;
    final u = d['users'] as Map?;
    final vehicleName = v == null ? 'Vehicle' : '${v['type']} ${v['id']}';
    final username = (u?['username'] ?? 'customer').toString();
    final start = DateTime.parse('${d['scheduled_start_time']}').toLocal();
    final startsNow =
        start.isBefore(DateTime.now().add(const Duration(minutes: 2)));
    final minutes = (d['blocks_booked'] as num).toInt() * 20;

    return FormScroll(
      children: [
        RentalSummaryCard(
          title: '$vehicleName · $username',
          subtitle:
              'Booking ${d['booking_code']} · ${startsNow ? 'Now' : formatClock(start)} · ${formatDuration(minutes)}',
          linkText: null,
          onLinkTap: () {},
        ),
        const SizedBox(height: 12),

        // ---- customer ----
        OutlinedCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((u?['full_name'] ?? 'Customer').toString(),
                  style: inter(15, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text((u?['phone'] ?? '-').toString(),
                  style: inter(13, color: AppColors.text2)),
              if (u?['email'] != null)
                Text(u!['email'].toString(),
                    style: inter(13, color: AppColors.text2)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- payment ----
        OutlinedCard(
          strong: true,
          error: _triedStart && !_paid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_paid ? 'Payment received' : 'Pay at counter'} · ${_total(d)}',
                      style: inter(15, weight: FontWeight.w600),
                    ),
                  ),
                  _paid
                      ? const RentalBadge('PAID')
                      : const RentalBadge('PENDING', filled: false),
                ],
              ),
              if (!_paid) ...[
                const SizedBox(height: 12),
                Text('How did the customer pay?',
                    style: inter(13, color: AppColors.text2)),
                const SizedBox(height: 8),
                OptionChips(
                  options: _payLabels,
                  selected: _payment,
                  onChanged: (i) => setState(() => _payment = i),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _busy ? null : () => _confirmPayment(d),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Confirm payment received',
                        style: inter(15,
                            weight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- IC ----
        OutlinedCard(
          error: _triedStart && !_icMatches,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.ink, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('IC on file',
                        style: inter(15, weight: FontWeight.w600)),
                  ),
                  SmallButton(
                      label: 'View IC',
                      primary: false,
                      onPressed: () => _viewIc(d)),
                ],
              ),
              const SizedBox(height: 12),
              AppCheckRow(
                value: _icMatches,
                onChanged: (x) => setState(() => _icMatches = x),
                text: 'Customer matches IC photo',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- condition ----
        const SectionTitle('Vehicle condition before handover'),
        const SizedBox(height: 10),
        ConditionChips(
          value: _condition,
          onChanged: (c) => setState(() => _condition = c),
        ),

        const Spacer(),
        const SizedBox(height: 16),
        // Grey until payment and the IC check are done. A tap on the grey
        // button still reaches the GestureDetector and says what is missing.
        GestureDetector(
          onTap: _canStart ? null : _onStartPressed,
          child: PrimaryButton(
            label: 'Start rental',
            loading: _busy,
            onPressed: _canStart ? () => _startRental(vehicleName) : null,
          ),
        ),
      ],
    );
  }
}