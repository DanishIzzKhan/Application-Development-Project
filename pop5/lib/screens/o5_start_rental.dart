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
  bool _icMatches = false;
  VehicleCondition _condition = VehicleCondition.good;

  void _confirmPayment() {
    // Later: Api.confirmCounterPayment(rental.id)
    setState(() => _paid = true);
    showToast(context, 'Payment of ${widget.rental.totalLabel} recorded.');
  }

  void _viewIc() {
    // Later: open the IC photo from the private ic-documents bucket
    // and write an IC access log entry (every view is recorded).
    showToast(context, 'IC viewer comes later. Every view will be logged.');
  }

  void _openCustomerDetails() {
    // Later: O3c Customer details.
    showToast(context, 'Customer details (O3c) is not built yet.');
  }

  void _startRental() {
    // Later: Api.startRental(rental.id, condition: _condition)
    // sets actual_start_time = now and status = 'active';
    // the customer app switches to C9 automatically.
    showToast(context, '${widget.rental.vehicleName} rental started.');
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

          // ---- IC (app customers) or deposit note (walk-ins) ----
          if (r.isWalkIn)
            _GreyNote('IC or deposit held: ${r.depositNote ?? '-'}')
          else
            OutlinedCard(
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
                    text: 'First visit: IC matches the customer',
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // ---- Condition ----
          const SectionTitle('Condition at collection'),
          const SizedBox(height: 10),
          ConditionChips(
            value: _condition,
            onChanged: (c) => setState(() => _condition = c),
          ),

          const Spacer(),
          const SizedBox(height: 16),
          if (!_paid) ...[
            Text(
              'Confirm payment first. Start rental is enabled once payment is received.',
              textAlign: TextAlign.center,
              style: inter(12, color: AppColors.hint),
            ),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: 'Start rental',
            onPressed: _paid ? _startRental : null, // disabled until paid
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

/// Light grey info box (#F0F0F0).
class _GreyNote extends StatelessWidget {
  final String text;
  const _GreyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: inter(13, color: AppColors.text2)),
    );
  }
}
