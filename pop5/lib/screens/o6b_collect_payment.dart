import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';

/// O6b Collect payment — opened from O6 when a late walk-in must pay at the
/// counter, or when an app customer's automatic late charge failed.
///
/// Pops with the payment method ('Card' | 'Cash' | 'TnG') once the owner
/// confirms the money was received, or null on Cancel. O6 then ends the rental.
class CollectPaymentScreen extends StatefulWidget {
  final OwnerRental rental;
  final int blocks; // late blocks to collect
  final double amount; // blocks × late price

  const CollectPaymentScreen({
    super.key,
    required this.rental,
    required this.blocks,
    required this.amount,
  });

  @override
  State<CollectPaymentScreen> createState() => _CollectPaymentScreenState();
}

/// One payment choice (radio card).
class _PayOption {
  final String value; // saved in payments.payment_method
  final String title;
  final String subtitle;
  const _PayOption(this.value, this.title, this.subtitle);
}

class _CollectPaymentScreenState extends State<CollectPaymentScreen> {
  // Sample saved card until the Api reads payment_methods.
  static const _sampleCard = 'Visa •••• 4417';

  static const _inApp = _PayOption('Card', 'Customer pays in the app',
      'Sends a “Pay extra” request to their phone');
  static const _cash =
      _PayOption('Cash', 'Cash', 'Owner collects cash at the counter');
  static const _qr = _PayOption('TnG', 'Touch ’n Go / bank QR',
      'Customer scans the shop’s QR at the counter');

  OwnerRental get _r => widget.rental;

  /// Walk-ins have no app, so they can't pay in the app.
  late final List<_PayOption> _options =
      _r.isWalkIn ? const [_cash, _qr] : const [_inApp, _cash, _qr];

  /// App customer: "pay in the app" first. Walk-in: Cash first.
  late _PayOption _selected = _options.first;

  bool _requestSent = false; // "Pay extra" request sent to the customer's phone

  void _select(_PayOption o) {
    setState(() => _selected = o);
    if (o == _inApp && !_requestSent) {
      // Later: Api.requestExtraPayment(rental.id, amount) -> notification
      // to the customer; their app opens C9d Pay extra charge.
      setState(() => _requestSent = true);
      showTopNotice(context,
          title: 'Pay extra request sent',
          lines: ['${_r.customerName} will see it on their phone.'],
          type: NoticeType.success);
    }
  }

  void _paymentReceived() {
    // Later: Api.recordPayment(rental.id, method: _selected.value,
    //   type: 'late_block', amount, confirmedBy: owner) inserts a payments row
    //   (status 'completed'). In-app payments update automatically instead.
    Navigator.of(context).pop(_selected.value);
  }

  @override
  void initState() {
    super.initState();
    // App customer: the in-app option is chosen by default, so send the
    // request straight away (like tapping it).
    if (_selected == _inApp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(_inApp);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Collect payment'),
      body: FormScroll(
        children: [
          // ---- Grey note ----
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    size: 20, color: AppColors.text2),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use this only when an automatic charge fails, '
                    'or for walk-in customers.',
                    style: inter(13, color: AppColors.text2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---- Amount card ----
          OutlinedCard(
            child: Column(
              children: [
                Text('Amount due', style: inter(14, color: AppColors.text2)),
                const SizedBox(height: 4),
                Text(formatRM(widget.amount),
                    style: inter(32, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Extra time · ${widget.blocks} × 20 min · ${_r.vehicleName}',
                  textAlign: TextAlign.center,
                  style: inter(13, color: AppColors.text2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ---- Payment choice ----
          const SectionTitle('How is the customer paying?'),
          const SizedBox(height: 10),
          for (final o in _options) ...[
            _RadioCard(
              option: o,
              selected: o == _selected,
              onTap: () => _select(o),
            ),
            const SizedBox(height: 8),
          ],

          // ---- Status card (app customers: why we are here) ----
          if (!_r.isWalkIn) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: AppColors.ink),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Auto-charge to $_sampleCard failed',
                            style: inter(14, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          _selected == _inApp
                              ? 'Waiting for payment… updates automatically when paid'
                              : 'Collect it at the counter instead',
                          style: inter(12, color: AppColors.text2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const RentalBadge('PENDING', filled: false),
                ],
              ),
            ),
          ],

          const Spacer(),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Payment received · end rental',
            onPressed: _paymentReceived,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(), // back to O6
              child: Text('Cancel',
                  style: inter(14,
                      weight: FontWeight.w600, color: AppColors.text2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card with a radio circle. Selected = dark 2px border + filled circle.
class _RadioCard extends StatelessWidget {
  final _PayOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RadioCard(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.dark : AppColors.divider,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.dark : AppColors.hint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title, style: inter(15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(option.subtitle,
                      style: inter(12, color: AppColors.text2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
