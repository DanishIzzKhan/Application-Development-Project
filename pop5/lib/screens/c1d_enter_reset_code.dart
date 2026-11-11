import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'c1e_reset_password.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;

  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otp = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final token = _otp.text.trim();
    if (token.isEmpty || token.length < 6) {
      showToast(context, 'Please enter the 6-digit verification code.');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.recovery,
      );

      if (!mounted) return;

      if (response.session != null) {
        // Authenticated temporary session created for password reset
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
      } else {
        showToast(context, 'Invalid or expired code.');
      }
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Verification failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(widget.email);
      if (mounted) showToast(context, 'A new code has been sent to ${widget.email}.');
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(color: AppColors.text2),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Enter OTP Code',
                  style: inter(24, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit verification code to ${widget.email}.',
                style: inter(14, color: AppColors.text2),
              ),
              const SizedBox(height: 32),
              AppField(
                label: 'Verification Code',
                hint: '123456',
                controller: _otp,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Verify & Continue',
                loading: _loading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _resendCode,
                  child: Text(
                    'Didn\'t receive code? Resend',
                    style: inter(14, weight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}