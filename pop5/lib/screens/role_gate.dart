import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c1_login.dart';
import 'c3_vehicles.dart';
import 'owner_shell.dart';

/// Shown right after login (C1) and when the app starts already signed in.
/// Asks Supabase for the user's role (users.role), then opens:
///   owner    -> OwnerShell (owner app, Rentals tab)
///   customer -> C3 Vehicles (also when no role is found)
/// Customers can never choose their role; it is set in Supabase only.
///
/// If the role can't be read (no internet, Supabase down, slow), it shows a
/// message with "Try again" / "Back to login" instead of spinning forever.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    setState(() => _failed = false);
    String? role;
    try {
      role = await Api.fetchMyRole().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('RoleGate: could not read role. $e');
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    // Later: owners go to O1b Verification code first.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            role == 'owner' ? const OwnerShell() : const VehiclesScreen(),
      ),
    );
  }

  /// Leave a half-signed-in state: sign out and show the login screen.
  Future<void> _backToLogin() async {
    try {
      await Api.signOut();
    } catch (_) {
      // Offline: still go back to the login screen.
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_failed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.dark),
              const SizedBox(height: 14),
              Text('Signing you in…', style: inter(14, color: AppColors.text2)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: AppColors.text2),
              const SizedBox(height: 14),
              Text("Couldn't sign you in",
                  textAlign: TextAlign.center,
                  style: inter(20, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: inter(14, color: AppColors.text2)),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Try again', onPressed: _route),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _backToLogin,
                child: Text('Back to login',
                    style: inter(14,
                        weight: FontWeight.w600, color: AppColors.text2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
