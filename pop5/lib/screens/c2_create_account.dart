import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/registration_data.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c2b_upload_ic.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _email, _phone, _code, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  void _sendCode() {
    showToast(context, 'SMS verification is not enabled yet.');
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = Api.normalizePhone(_phone.text);

    setState(() => _busy = true);
    try {
      final conflict = await Api.signupConflict(_username.text.trim(), phone);
      if (!mounted) return;
      if (conflict == 'username') {
        showToast(context, 'That username is already taken.');
        return;
      }
      if (conflict == 'phone') {
        showToast(context, 'That phone number is already registered.');
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UploadIcScreen(
          data: RegistrationData(
            fullName: _fullName.text.trim(),
            username: _username.text.trim(),
            email: _email.text.trim(),
            phone: phone,
            password: _password.text,
          ),
        ),
      ));
    } on PostgrestException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: const AppHeader(title: 'Create account', trailing: 'Step 1 of 2'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: FormScroll(
            children: [
              AppField(
                label: 'Full name',
                hint: 'e.g. [Full name as in IC]',
                controller: _fullName,
                textInputAction: TextInputAction.next,
                validator: (v) => _required(v, 'Enter your full name'),
              ),
              gap,
              AppField(
                label: 'Username (shown on your profile)',
                hint: 'e.g. ahmad_rides',
                controller: _username,
                textInputAction: TextInputAction.next,
                validator: (v) => RegExp(r'^[a-zA-Z0-9_]{3,20}$')
                        .hasMatch((v ?? '').trim())
                    ? null
                    : '3-20 letters, numbers or _',
              ),
              gap,
              AppField(
                label: 'Email',
                hint: 'e.g. name@email.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                        ? null
                        : 'Enter a valid email',
              ),
              gap,
              AppField(
                label: 'Phone number',
                hint: 'e.g. 012-345 6789',
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  final n = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length;
                  return (n >= 9 && n <= 13) ? null : 'Enter a valid phone number';
                },
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppField(
                      label: 'Verification code (SMS)',
                      hint: '6-digit code',
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _sendCode,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.dark, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text('Send code',
                          style: inter(14, weight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              gap,
              AppField(
                label: 'Password',
                hint: 'At least 8 characters',
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) =>
                    (v ?? '').length >= 8 ? null : 'At least 8 characters',
              ),
              const Spacer(),
              const SizedBox(height: 16),
              PrimaryButton(
                  label: 'Next: upload IC', loading: _busy, onPressed: _next),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Text.rich(
                  TextSpan(
                    style: inter(14, color: AppColors.text2),
                    children: [
                      const TextSpan(text: 'Already have an account? '),
                      TextSpan(
                          text: 'Log in',
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