import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/hitpay_api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// C7 Waiting for payment. Opened after the HitPay payment page was opened.
/// Every 4 seconds it asks the server if HitPay confirmed the payment (the webhook
/// normally does it first), then reads the booking status.
/// Pops with true when paid, false when the customer cancels.
class WaitingPaymentScreen extends StatefulWidget {
  final String bookingId; // rentals.id
  final String paymentMethod; // 'TnG' | 'Bank QR' | 'Card' (used when retrying)
  final String? checkoutUrl; // HitPay page link, to open it again

  const WaitingPaymentScreen({
    super.key,
    required this.bookingId,
    this.paymentMethod = 'TnG',
    this.checkoutUrl,
  });

  @override
  State<WaitingPaymentScreen> createState() => _WaitingPaymentScreenState();
}

class _WaitingPaymentScreenState extends State<WaitingPaymentScreen> {
  bool _isChecking = true;
  bool _isFailed = false;
  bool _busy = false;
  String? _checkoutUrl;
  String _statusMessage =
      'Complete the payment on the HitPay page. This screen updates by itself when it is confirmed.';
  Timer? _pollTimer;
  bool _polling = false; // one check at a time

  @override
  void initState() {
    super.initState();
    _checkoutUrl = widget.checkoutUrl;
    _startPaymentPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPaymentPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (_polling) return;
      _polling = true;
      try {
        // Ask HitPay (through the server) first; ignore errors and try again next time.
        try {
          await HitpayApi.checkPayment(widget.bookingId);
        } catch (_) {}

        final response = await Supabase.instance.client
            .from('rentals')
            .select('status')
            .eq('id', widget.bookingId)
            .single();

        final status = response['status'] as String?;
        if (!mounted) return;

        // 'ready' = paid, waiting for handover; later statuses also mean paid.
        if (status == 'ready' ||
            status == 'checked_in' ||
            status == 'active' ||
            status == 'completed') {
          timer.cancel();
          setState(() {
            _isChecking = false;
            _isFailed = false;
          });
        } else if (status == 'cancelled' || status == 'expired') {
          timer.cancel();
          setState(() {
            _isChecking = false;
            _isFailed = true;
            _statusMessage =
                'Payment failed or was cancelled. Please try again.';
          });
        }
      } catch (_) {
        // Silent during the polling interval.
      } finally {
        _polling = false;
      }
    });
  }

  Future<void> _openPaymentPage() async {
    final url = _checkoutUrl;
    if (url == null) {
      await _retryPayment();
      return;
    }
    try {
      await HitpayApi.openCheckout(url);
    } catch (e) {
      if (mounted) showToast(context, '$e');
    }
  }

  /// Creates a new HitPay payment request and opens it.
  Future<void> _retryPayment() async {
    setState(() => _busy = true);
    try {
      final url = await HitpayApi.createPayment(
          rentalId: widget.bookingId, method: widget.paymentMethod);
      await HitpayApi.openCheckout(url);
      if (!mounted) return;
      setState(() {
        _checkoutUrl = url;
        _isChecking = true;
        _isFailed = false;
        _statusMessage =
            'Complete the payment on the HitPay page. This screen updates by itself when it is confirmed.';
      });
      _startPaymentPolling();
    } catch (e) {
      if (mounted) showToast(context, 'Could not open the payment page: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelBooking() async {
    try {
      await Supabase.instance.client
          .from('rentals')
          .update({'status': 'cancelled'}).eq('id', widget.bookingId);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Waiting for Payment'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isChecking
                      ? const CircularProgressIndicator(
                          color: AppColors.dark,
                          strokeWidth: 3,
                        )
                      : _isFailed
                          ? const Icon(Icons.error_outline,
                              size: 48, color: Colors.red)
                          : const Icon(Icons.check_circle_outline,
                              size: 48, color: AppColors.dark),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isChecking
                    ? 'Processing Payment...'
                    : _isFailed
                        ? 'Payment Failed'
                        : 'Payment Successful!',
                style: inter(20, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isChecking
                    ? 'Booking ${widget.bookingId}\n\n$_statusMessage'
                    : _isFailed
                        ? _statusMessage
                        : 'Your payment has been verified and confirmed. You can now proceed to collect your vehicle.',
                style: inter(14, color: AppColors.text2),
                textAlign: TextAlign.center,
              ),
              if (_isChecking) ...[
                const SizedBox(height: 14),
                TextButton(
                  onPressed: _busy ? null : _openPaymentPage,
                  child: Text('Open the payment page again',
                      style: inter(14, weight: FontWeight.w600)),
                ),
              ],
              const Spacer(),
              if (_isFailed) ...[
                PrimaryButton(
                  label: 'Retry Payment',
                  loading: _busy,
                  onPressed: _retryPayment,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel Booking',
                      style: inter(14,
                          weight: FontWeight.w600, color: AppColors.ink)),
                ),
              ] else ...[
                PrimaryButton(
                  label: _isChecking
                      ? 'Waiting for confirmation...'
                      : 'View Receipt (C8)',
                  onPressed:
                      _isChecking ? null : () => Navigator.pop(context, true),
                ),
                if (_isChecking) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cancelBooking,
                    child: Text('Cancel',
                        style: inter(14, color: AppColors.text2)),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
