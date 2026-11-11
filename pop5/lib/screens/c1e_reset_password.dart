import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'c1_login.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _newPassword.text;
    final confirm = _confirmPassword.text;

    if (password.isEmpty || confirm.isEmpty) {
      showToast(context, 'Please fill in both password fields.');
      return;
    }

    if (password.length < 6) {
      showToast(context, 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirm) {
      showToast(context, 'Passwords do not match.');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );

      if (!mounted) return;

      showToast(context, 'Password updated successfully! Please log in.');
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Failed to update password: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create New Password',
                  style: inter(24, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Your new password must be different from previously used passwords.',
                style: inter(14, color: AppColors.text2),
              ),
              const SizedBox(height: 32),
              AppField(
                label: 'New Password',
                hint: '••••••••',
                controller: _newPassword,
                obscure: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Confirm Password',
                hint: '••••••••',
                controller: _confirmPassword,
                obscure: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Reset Password',
                loading: _loading,
                onPressed: _updatePassword,
              ),
            ],
          ),
        ),
      ),
    );
  }
}