import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rental.dart';
import '../services/owner_api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';
import 'o3c_customer_details.dart';

/// O5 Start rental — opened from O3 ("Open" / "Start"), O3b (scanned QR)
/// and O4 (new walk-in). Pops with `true` when the rental has started.
///
/// Real bookings (rental.fromDatabase) are saved in Supabase:
///   Confirm payment -> owner_confirm_payment (pending_payment -> ready)
///   View IC         -> logged in ic_access_log, photos from the private bucket
///   Start rental    -> owner_start_rental (ready -> active); the customer's
///                      phone switches to the active rental by itself.
/// Sample bookings and app-only walk-ins only change in the app.
class StartRentalScreen extends StatefulWidget {
  final OwnerRental rental;
  const StartRentalScreen({super.key, required this.rental});

  @override
  State<StartRentalScreen> createState() => _StartRentalScreenState();
}

class _StartRentalScreenState extends State<StartRentalScreen> {
  // Chip labels and the matching value saved in payments.payment_method.
  static const _payLabels = ['Cash', 'Touch ’n Go', 'Bank QR'];
  static const _payValues = ['Cash', 'TnG', 'Bank QR'];

  late OwnerRental _r = widget.rental;
  late bool _paid = _r.isPaid; // already paid online -> true
  bool _icMatches = false; // checked again on every visit
  VehicleCondition _condition = VehicleCondition.good;
  int _payment = 0; // Cash by default
  String? _paidWith; // method confirmed on this screen
  bool _busy = false; // a database call is running

  /// Becomes true when the owner taps Start before everything is done.
  /// Only then do the red reminders appear.
  bool _triedStart = false;

  /// Everyone must have paid. App customers also need the IC tick box;
  /// walk-ins gave their details at the counter on O4.
  bool get _canStart => _paid && (_r.isWalkIn || _icMatches);

  /// Lines shown under the Start button: what is still missing.
  List<String> get _missing => [
        if (!_paid) 'Confirm payment to start',
        if (!_r.isWalkIn && !_icMatches) 'Tick the IC check to start',
      ];

  @override
  void initState() {
    super.initState();
    if (_r.fromDatabase) _refresh();
  }

  /// Reloads the booking, e.g. the customer may have just paid online.
  Future<void> _refresh() async {
    try {
      final fresh = await OwnerApi.fetchRental(_r.id);
      if (!mounted) return;
      setState(() {
        _r = fresh;
        _paid = fresh.isPaid;
      });
    } catch (e) {
      debugPrint('Start rental: could not reload booking. $e');
    }
  }

  /// Runs a database call with the button showing a spinner, and turns an
  /// error into a red notification. Returns true when it worked.
  Future<bool> _save(String failTitle, Future<void> Function() call) async {
    setState(() => _busy = true);
    try {
      await call();
      return true;
    } on PostgrestException catch (e) {
      // Messages from our database functions are written for the owner,
      // e.g. "This booking has already started."
      if (mounted) {
        showTopNotice(context,
            title: failTitle, lines: [e.message], type: NoticeType.error);
      }
    } catch (e) {
      debugPrint('$failTitle: $e');
      if (mounted) {
        showTopNotice(context,
            title: failTitle,
            lines: ['Check your internet connection and try again.'],
            type: NoticeType.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _confirmPayment() async {
    if (_r.fromDatabase) {
      final ok = await _save("Couldn't record the payment",
          () => OwnerApi.confirmPayment(_r.id, _payValues[_payment]));
      if (!ok || !mounted) return;
    }
    setState(() {
      _paid = true;
      _paidWith = _payValues[_payment];
    });
    showTopNotice(context,
        title: 'Payment of ${_r.totalLabel} recorded',
        type: NoticeType.success);
  }

  void _viewIc() {
    // Asks first. Real bookings: the view is recorded, then the photos load.
    showIcViewer(
      context,
      _r.customerName,
      front: _r.walkInIcFront,
      back: _r.walkInIcBack,
      load: _r.fromDatabase ? () => OwnerApi.openIc(_r) : null,
    );
  }

  void _openCustomerDetails() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailsScreen(rental: _r),
    ));
  }

  /// Grey Start button tapped: show a notification at the top saying
  /// what is missing, and mark the cards that need doing in red.
  void _onStartPressed() {
    setState(() => _triedStart = true);
    showTopNotice(context,
        title: "Can't start rental yet",
        lines: _missing,
        type: NoticeType.error);
  }

  Future<void> _startRental() async {
    if (_r.fromDatabase) {
      final ok = await _save("Couldn't start the rental",
          () => OwnerApi.startRental(_r.id, _condition.label));
      if (!ok || !mounted) return;
    }
    showTopNotice(context,
        title: '${_r.vehicleName} rental started', type: NoticeType.success);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;

    return Scaffold(
      appBar: const AppHeader(title: 'Start rental'),
      body: FormScroll(
        children: [
          RentalSummaryCard(
            title: r.title,
            subtitle:
                'Booking ${r.bookingCode} · ${r.startLabel(DateTime.now())} · ${r.durationLabel}',
            linkText: 'View customer details ›',
            onLinkTap: _openCustomerDetails,
          ),
          const SizedBox(height: 12),

          // ---- Payment ----
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
                        '${_paymentLabel(r)} · ${r.totalLabel}',
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
                      onPressed: _busy ? null : _confirmPayment,
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

          // ---- IC: tick box for app customers; walk-ins get View IC only
          //      if a photo was taken on O4 ----
          if (r.isWalkIn)
            OutlinedCard(
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.ink, size: 22),
                  const SizedBox(width: 8),
                  // Photo is optional on O4: View IC only if one was taken.
                  Expanded(
                    child: Text(
                      r.walkInIcPhotoTaken
                          ? 'IC photo taken ✓'
                          : 'No IC photo taken',
                      style: inter(15,
                          weight: FontWeight.w600,
                          color: r.walkInIcPhotoTaken
                              ? AppColors.ink
                              : AppColors.hint),
                    ),
                  ),
                  if (r.walkInIcPhotoTaken)
                    SmallButton(
                        label: 'View IC', primary: false, onPressed: _viewIc),
                ],
              ),
            )
          else
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
                          label: 'View IC', primary: false, onPressed: _viewIc),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppCheckRow(
                    value: _icMatches,
                    onChanged: (v) => setState(() => _icMatches = v),
                    text: 'Customer matches IC photo',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // ---- Condition ----
          const SectionTitle('Vehicle condition before handover'),
          const SizedBox(height: 10),
          ConditionChips(
            value: _condition,
            onChanged: (c) => setState(() => _condition = c),
          ),

          const Spacer(),
          const SizedBox(height: 16),
          // Grey (disabled) until ready. A tap on the grey button still
          // reaches the GestureDetector and shows the top notification.
          GestureDetector(
            onTap: _canStart || _busy ? null : _onStartPressed,
            child: PrimaryButton(
              label: 'Start rental',
              loading: _busy,
              onPressed: _canStart ? _startRental : null,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(OwnerRental r) {
    if (!_paid) return 'Pay at counter';
    if (r.paidOnline) return 'Paid online';
    return switch (_paidWith ?? r.paymentMethod) {
      'TnG' => 'Paid · Touch ’n Go',
      'Bank QR' => 'Paid · Bank QR',
      'Cash' => 'Paid · Cash',
      'Card' => 'Paid · Card',
      _ => 'Paid at counter',
    };
  }
}
