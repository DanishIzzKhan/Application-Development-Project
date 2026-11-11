import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O6c Rental completed — shown after O6 (or O6b) ends a rental.
/// "Back to rentals" / X returns to O3 and clears the screens in between.
class RentalCompletedScreen extends StatelessWidget {
  final OwnerRental rental;
  final DateTime returnTime;
  final int lateMinutes;
  final double totalPaid;
  final String paymentLine; // e.g. "Late charge auto-charged ✓"
  final double refunded; // 0 if nothing is refunded
  final VehicleCondition condition;
  final List<ChargeRow> charges; // same rows as the O6 table (receipt)

  const RentalCompletedScreen({
    super.key,
    required this.rental,
    required this.returnTime,
    required this.lateMinutes,
    required this.totalPaid,
    required this.paymentLine,
    required this.refunded,
    required this.condition,
    required this.charges,
  });

  bool get _underRepair => condition == VehicleCondition.damaged;

  /// Customer name without the "Walk-in: " prefix for the summary.
  String get _customer => rental.customerName.replaceFirst('Walk-in: ', '');

  int get _totalMinutes {
    final m = returnTime.difference(rental.scheduledStart).inMinutes;
    return m > 0 ? m : 0;
  }

  /// Back to O3: pop every screen above OwnerShell.
  void _backToRentals(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Walk-ins have no app, so the owner shows the receipt on screen.
  void _showReceipt(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receipt · ${rental.bookingCode}',
            style: inter(18, weight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${rental.vehicleName} · $_customer',
                  style: inter(14, weight: FontWeight.w600)),
              Text(
                '${formatClock(rental.scheduledStart)} – ${formatClock(returnTime)}'
                ' · ${formatDuration(_totalMinutes)}',
                style: inter(13, color: AppColors.text2),
              ),
              const SizedBox(height: 10),
              ChargesTable(rows: charges, total: formatRM(totalPaid)),
              const SizedBox(height: 8),
              Text('Thank you for riding with ISYGEAR!',
                  textAlign: TextAlign.center,
                  style: inter(12, color: AppColors.hint)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: inter(14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Android back button also goes back to O3 (not to O6).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToRentals(context);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 60,
          automaticallyImplyLeading: false, // no back arrow
          titleSpacing: 16,
          title: Text('Rental completed',
              style: inter(20, weight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.ink),
              onPressed: () => _backToRentals(context),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1.5),
            child: SizedBox(
              height: 1.5,
              width: double.infinity,
              child: ColoredBox(color: AppColors.divider),
            ),
          ),
        ),
        body: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 32),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    // ---- Check circle + title ----
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            size: 40, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Rental ended',
                        textAlign: TextAlign.center,
                        style: inter(22, weight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      _underRepair
                          ? '${rental.vehicleName} needs repair before the next rental.'
                          : '${rental.vehicleName} is ready for the next customer.',
                      textAlign: TextAlign.center,
                      style: inter(14, color: AppColors.text2),
                    ),
                    const SizedBox(height: 18),

                    // ---- Summary card ----
                    OutlinedCard(
                      child: Column(
                        children: [
                          _row('Vehicle', rental.vehicleName),
                          _row('Customer', _customer),
                          _row('Total time', formatDuration(_totalMinutes)),
                          _row('Late by',
                              lateMinutes > 0 ? '$lateMinutes min' : 'On time'),
                          _row('Total paid', formatRM(totalPaid), bold: true),
                          _row('Payment', paymentLine),
                          if (refunded > 0)
                            _row('Refund', '${formatRM(refunded)} · automatic'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ---- Vehicle status ----
                    OutlinedCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Vehicle status',
                                style: inter(14, weight: FontWeight.w600)),
                          ),
                          _underRepair
                              ? const RentalBadge('UNDER REPAIR', filled: false)
                              : const RentalBadge('AVAILABLE'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---- Receipt line ----
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 20, color: AppColors.text2),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rental.isWalkIn
                                ? 'Walk-in: show the receipt on screen'
                                : 'Final receipt sent to the customer',
                            style: inter(13, color: AppColors.text2),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),
                    const SizedBox(height: 16),
                    if (rental.isWalkIn) ...[
                      SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => _showReceipt(context),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.dark, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Show receipt (for walk-in customers)',
                              style: inter(15,
                                  weight: FontWeight.w600,
                                  color: AppColors.dark)),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    PrimaryButton(
                      label: 'Back to rentals',
                      onPressed: () => _backToRentals(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Text(label, style: inter(14, color: AppColors.text2))),
            Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: inter(14,
                      weight: bold ? FontWeight.w700 : FontWeight.w600)),
            ),
          ],
        ),
      );
}
