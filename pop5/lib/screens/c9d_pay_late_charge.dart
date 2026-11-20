import 'package:flutter/material.dart';

import '../models/active_rental.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c8_receipt.dart';

enum _LateMethod { touchNGo, duitNow }

/// C9d Pay late charge: opened from C9c ("Charge failed? Pay here").
/// TESTING: no payment gateway yet, so "Pay" only opens the receipt.
class PayLateChargeScreen extends StatefulWidget {
  final String rentalId;
  const PayLateChargeScreen({super.key, required this.rentalId});

  @override
  State<PayLateChargeScreen> createState() => _PayLateChargeScreenState();
}

class _PayLateChargeScreenState extends State<PayLateChargeScreen> {
  ActiveRental? _r;
  String? _error;
  bool _loading = true;
  _LateMethod _method = _LateMethod.touchNGo;
  final DateTime _now = DateTime.now();

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
      final row = await supabase
          .from('rentals')
          .select('*, vehicles(id, type)')
          .eq('id', widget.rentalId)
          .single();
      if (mounted) setState(() => _r = ActiveRental.fromMap(row));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pay() {
    // Later: create a payments row (payment_type 'late_block') through the gateway.
    Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ReceiptScreen(bookingId: widget.rentalId)));
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: const AppHeader(title: 'Pay late charge'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : r == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load this rental.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                        ),
                        TextButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  )
                : _content(r),
      ),
    );
  }

  Widget _content(ActiveRental r) {
    final blocks = r.lateBlocks(_now);
    final lateMin = r.lateBy(_now).inMinutes;
    final returned = r.actualEnd ?? _now;
    final due = rmOrX(r.lateCharge(_now));

    Widget row(String left, String right, {bool bold = false}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left,
                style: inter(14,
                    weight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? AppColors.ink : AppColors.text2)),
            Text(right,
                style: inter(bold ? 16 : 14,
                    weight: bold ? FontWeight.w700 : FontWeight.w400)),
          ],
        );

    return FormScroll(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.dark, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Automatic charge to Visa •••• 4417 failed. Please pay to complete your rental.',
                  style: inter(14, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Column(
            children: [
              row('Booked until', clockLabel(r.end)),
              const SizedBox(height: 8),
              row('Returned at', clockLabel(returned)),
              const SizedBox(height: 8),
              row('Late by', '$lateMin min (${r.graceMinutes} min free)'),
              const SizedBox(height: 8),
              row('Extra time ($blocks × 20 min)', due),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1.5, color: AppColors.divider),
              const SizedBox(height: 10),
              row('Amount due', due, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Pay with', style: inter(14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        _option("Touch 'n Go eWallet", _method == _LateMethod.touchNGo,
            () => setState(() => _method = _LateMethod.touchNGo)),
        const SizedBox(height: 10),
        _option('DuitNow / bank QR', _method == _LateMethod.duitNow,
            () => setState(() => _method = _LateMethod.duitNow)),
        const SizedBox(height: 12),
        Text(
          'After you pay, the owner is told and your rental is completed. Your saved card is not charged again.',
          style: inter(12, color: AppColors.text2),
        ),
        const Spacer(),
        const SizedBox(height: 14),
        PrimaryButton(label: 'Pay $due', onPressed: _pay),
      ],
    );
  }

  Widget _option(String title, bool selected, VoidCallback onTap) {
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
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 22,
              color: selected ? AppColors.dark : AppColors.border,
            ),
            const SizedBox(width: 12),
            Text(title, style: inter(15, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}