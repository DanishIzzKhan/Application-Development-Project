import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O5 Start rental — opened from O3 ("Open" / "Start") and later from O3b / O4.
/// Pops with `true` when the owner starts the rental, so O3 can move the row to Active.
class StartRentalScreen extends StatefulWidget {
  final OwnerRental rental;
  const StartRentalScreen({super.key, required this.rental});

  @override
  State<StartRentalScreen> createState() => _StartRentalScreenState();
}

class _StartRentalScreenState extends State<StartRentalScreen> {
  late bool _paid = widget.rental.isPaid; // already paid online -> true
  bool _icMatches = false; // checked again on every visit
  VehicleCondition _condition = VehicleCondition.good;

  /// Becomes true when the owner taps Start before everything is done.
  /// Only then do the red reminders appear.
  bool _triedStart = false;

  /// Walk-ins paid at the counter on O4, so they can start straight away.
  /// App customers need payment AND the IC tick box.
  bool get _canStart => widget.rental.isWalkIn || (_paid && _icMatches);

  /// Lines shown under the Start button: what is still missing.
  List<String> get _missing => widget.rental.isWalkIn
      ? const []
      : [
          if (!_paid) 'Confirm payment to start',
          if (!_icMatches) 'Tick the IC check to start',
        ];

  void _confirmPayment() {
    // Later: Api.confirmCounterPayment(rental.id)
    setState(() => _paid = true);
    showTopNotice(context,
        title: 'Payment of ${widget.rental.totalLabel} recorded',
        type: NoticeType.success);
  }

  void _viewIc() {
    // Later: open the IC photo from the private ic-documents bucket
    // and write an IC access log entry (every view is recorded).
    showTopNotice(context,
        title: 'IC viewer: coming soon',
        lines: ['Every IC view will be recorded.']);
  }

  void _openCustomerDetails() {
    // Later: O3c Customer details.
    showTopNotice(context, title: 'Customer details: coming soon');
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

  void _startRental() {
    // Later: Api.startRental(rental.id, condition: _condition)
    // sets actual_start_time = now and status = 'active';
    // the customer app switches to C9 automatically.
    showTopNotice(context,
        title: '${widget.rental.vehicleName} rental started',
        type: NoticeType.success);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.rental;

    return Scaffold(
      appBar: const AppHeader(title: 'Start rental'),
      body: FormScroll(
        children: [
          RentalSummaryCard(
            title: r.title,
            subtitle:
                'Booking ${r.bookingCode} · ${r.startLabel(DateTime.now())} · ${r.durationLabel}',
            linkText: r.isWalkIn ? null : 'View customer details ›',
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
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _confirmPayment,
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

          // ---- IC: tick box for app customers, photo status for walk-ins ----
          if (r.isWalkIn)
            OutlinedCard(
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppColors.ink, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      r.walkInIcPhotoTaken
                          ? 'IC photo taken ✓'
                          : 'IC photo not taken yet',
                      style: inter(15,
                          weight: FontWeight.w600,
                          color: r.walkInIcPhotoTaken
                              ? AppColors.ink
                              : AppColors.hint),
                    ),
                  ),
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
                          label: 'View IC',
                          primary: false,
                          onPressed: _viewIc),
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
            onTap: _canStart ? null : _onStartPressed,
            child: PrimaryButton(
              label: 'Start rental',
              onPressed: _canStart ? _startRental : null,
            ),
          ),
        ],
      ),
    );
  }

  String _paymentLabel(OwnerRental r) {
    if (!_paid) return 'Pay at counter';
    if (r.isWalkIn) return 'Paid at counter';
    return r.paidOnline ? 'Paid online' : 'Paid at counter';
  }
}
