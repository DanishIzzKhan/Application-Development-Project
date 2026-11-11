import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c2_create_account.dart';
import 'role_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_id.text.trim().isEmpty || _password.text.isEmpty) {
      showToast(context, 'Enter your phone number or email and password.');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.signIn(_id.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        // RoleGate checks users.role: owner -> owner app, customer -> C3.
        MaterialPageRoute(builder: (_) => const RoleGate()),
        (_) => false,
      );
    } on AuthException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Could not log in: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: DashedBox(
                  width: 88,
                  height: 88,
                  child: Text('LOGO',
                      style: inter(12, color: AppColors.text2)),
                ),
              ),
              const SizedBox(height: 10),
              Text('ISYGEAR Rentals',
                  textAlign: TextAlign.center,
                  style: inter(24, weight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Bicycle and scooter rental at Kulai Park',
                  textAlign: TextAlign.center,
                  style: inter(14, color: AppColors.text2)),
              const SizedBox(height: 36),
              AppField(
                label: 'Phone number or email',
                hint: 'e.g. 012-345 6789',
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppField(
                label: 'Password',
                hint: '••••••••',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => showToast(
                      context, 'Forgot password (C1c) is not built yet.'),
                  child: Text('Forgot password?',
                      style: inter(14, weight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Log in', loading: _loading, onPressed: _login),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const CreateAccountScreen())),
                child: Text.rich(
                  TextSpan(
                    style: inter(14, color: AppColors.text2),
                    children: [
                      const TextSpan(text: 'New customer? '),
                      TextSpan(
                          text: 'Create an account',
                          style: inter(14, weight: FontWeight.w600)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
