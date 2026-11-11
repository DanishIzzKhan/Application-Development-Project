import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'c1d_enter_reset_code.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final emailText = _email.text.trim();
    if (emailText.isEmpty) {
      showToast(context, 'Please enter your email address.');
      return;
    }

    setState(() => _loading = true);
    try {
      // If using custom Api wrapper: await Api.resetPasswordForEmail(emailText);
      await Supabase.instance.client.auth.resetPasswordForEmail(emailText);
      if (!mounted) return;

      showToast(context, 'Reset code sent to your email.');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(email: emailText),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Failed to send reset code: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
              Text('Forgot Password',
                  style: inter(24, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Enter your registered email address to receive a recovery code.',
                style: inter(14, color: AppColors.text2),
              ),
              const SizedBox(height: 32),
              AppField(
                label: 'Email address',
                hint: 'e.g. user@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Send Code',
                loading: _loading,
                onPressed: _sendResetCode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}