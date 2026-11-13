import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c7_waiting_for_payment.dart';
import 'c8_receipt.dart';

enum PayMethod { touchNGo, duitNow, counter }

/// TESTING ONLY: true = skip C7 (waiting for payment) and go straight to the
/// receipt (C8) as if the payment succeeded. Set to false once real payment
/// confirmation is connected.
const bool kSkipPaymentWait = true;

/// C6 Payment (Touch 'n Go / DuitNow selected) and
/// C6b Payment - pay at counter (counter selected): one screen, two states.
class PaymentScreen extends StatefulWidget {
  final Vehicle vehicle;
  final DateTime? start; // null = starts now
  final int durationMinutes;
  final double total;

  /// Placeholder until saved cards (C14e) are wired to payment_methods.
  final String savedCardLabel;

  const PaymentScreen({
    super.key,
    required this.vehicle,
    required this.start,
    required this.durationMinutes,
    required this.total,
    this.savedCardLabel = 'Visa •••• 4417',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PayMethod _method = PayMethod.touchNGo; // wireframe C6 default
  bool _loading = false;

  String get _totalLabel => 'RM ${widget.total.toStringAsFixed(2)}';
  String get _durationLabel =>
      '${widget.durationMinutes ~/ 60} hr ${widget.durationMinutes % 60} min';

  String get _buttonLabel => _method == PayMethod.counter
      ? 'Confirm booking · pay at counter'
      : 'Pay $_totalLabel now';

  /// Saves the booking (pending_payment), opens C7 to wait for payment and,
  /// once paid, C8 for the receipt. Pops with true so C5 and C3 refresh.
  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      final id = await Api.createBooking(
        vehicle: widget.vehicle,
        start: widget.start ?? DateTime.now(),
        durationMinutes: widget.durationMinutes,
      );
      if (!mounted) return;

      final paid = kSkipPaymentWait
          ? true
          : await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                  builder: (_) => WaitingPaymentScreen(bookingId: id)),
            );
      if (!mounted) return;

      if (paid == true) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScreen(bookingId: id)),
        );
        // C8 "Done" pops back to the first screen, so C6 may already be gone.
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Could not create booking: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Payment'),
      body: SafeArea(
        child: FormScroll(
          children: [
            _summaryCard(),
            const SizedBox(height: 14),
            Text('Choose payment method',
                style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            _PayOption(
              title: "Touch 'n Go eWallet",
              subtitle: 'Pay now through the payment gateway',
              selected: _method == PayMethod.touchNGo,
              onTap: () => setState(() => _method = PayMethod.touchNGo),
            ),
            const SizedBox(height: 14),
            _PayOption(
              title: 'DuitNow / bank QR',
              subtitle: 'Scan with your banking app',
              selected: _method == PayMethod.duitNow,
              onTap: () => setState(() => _method = PayMethod.duitNow),
            ),
            const SizedBox(height: 14),
            _PayOption(
              title: 'Pay at the counter',
              subtitle: 'Cash or QR at the shop · owner confirms your payment',
              selected: _method == PayMethod.counter,
              onTap: () => setState(() => _method = PayMethod.counter),
            ),
            const Spacer(),
            const SizedBox(height: 14),
            PrimaryButton(
                label: _buttonLabel, loading: _loading, onPressed: _confirm),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    Widget row(String left, String right, {Color color = AppColors.ink}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: inter(14, color: color)),
            Text(right, style: inter(14, color: color)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking summary', style: inter(14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          row(widget.vehicle.name, _durationLabel),
          const SizedBox(height: 8),
          row('Start',
              widget.start == null ? 'Now' : formatDateTime(widget.start!),
              color: AppColors.text2),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card_outlined,
                      size: 16, color: AppColors.text2),
                  const SizedBox(width: 6),
                  Text('Late charges (auto)',
                      style: inter(14, color: AppColors.text2)),
                ],
              ),
              Text(widget.savedCardLabel,
                  style: inter(14, color: AppColors.text2)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: inter(16, weight: FontWeight.w700)),
              Text(_totalLabel, style: inter(16, weight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PayOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.dark : AppColors.border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? AppColors.dark : AppColors.border,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: inter(15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: inter(12, color: AppColors.text2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}