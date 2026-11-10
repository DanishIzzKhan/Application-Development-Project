import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WaitingPaymentScreen extends StatefulWidget {
  final String bookingId;
  const WaitingPaymentScreen({super.key, required this.bookingId});

  @override
  State<WaitingPaymentScreen> createState() => _WaitingPaymentScreenState();
}

class _WaitingPaymentScreenState extends State<WaitingPaymentScreen> {
  bool _isChecking = true;
  bool _isFailed = false;
  String _statusMessage = 'Please complete the payment on your gateway app. We are waiting for confirmation...';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPaymentPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPaymentPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await Supabase.instance.client
            .from('bookings')
            .select('status')
            .eq('id', widget.bookingId)
            .single();

        final status = response['status'] as String?;
        if (!mounted) return;

        if (status == 'paid' || status == 'confirmed') {
          timer.cancel();
          setState(() {
            _isChecking = false;
            _isFailed = false;
          });
        } else if (status == 'failed' || status == 'cancelled') {
          timer.cancel();
          setState(() {
            _isChecking = false;
            _isFailed = true;
            _statusMessage = 'Payment failed or was cancelled. Please try again.';
          });
        }
      } catch (e) {
        // Silent catch during polling interval
      }
    });
  }

  Future<void> _retryPayment() async {
    setState(() {
      _isChecking = true;
      _isFailed = false;
      _statusMessage = 'Retrying payment verification...';
    });
    _startPaymentPolling();
  }

  Future<void> _cancelBooking() async {
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', widget.bookingId);
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
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: _isChecking
                      ? const CircularProgressIndicator(
                          color: AppColors.dark, strokeWidth: 3,
                        )
                      : _isFailed
                          ? const Icon(Icons.error_outline, size: 48, color: Colors.red)
                          : const Icon(Icons.check_circle_outline, size: 48, color: AppColors.dark),
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
                    ? 'Booking ID: ${widget.bookingId.substring(0, 8)}\n\n$_statusMessage'
                    : _isFailed
                        ? _statusMessage
                        : 'Your payment has been verified and confirmed. You can now proceed to collect your vehicle.',
                style: inter(14, color: AppColors.text2),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_isFailed) ...[
                PrimaryButton(
                  label: 'Retry Payment',
                  onPressed: _retryPayment,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cancelBooking,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel Booking', style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
                ),
              ] else ...[
                PrimaryButton(
                  label: _isChecking ? 'Waiting for confirmation...' : 'View Receipt (C8)',
                  onPressed: _isChecking ? null : () => Navigator.pop(context, true),
                ),
                if (_isChecking) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cancelBooking,
                    child: Text('Cancel', style: inter(14, color: AppColors.text2)),
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