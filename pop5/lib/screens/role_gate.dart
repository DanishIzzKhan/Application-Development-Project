import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import 'c3_vehicles.dart';
import 'owner_shell.dart';

/// Shown right after login (C1) and when the app starts already signed in.
/// Asks Supabase for the user's role (users.role), then opens:
///   owner    -> OwnerShell (owner app, Rentals tab)
///   customer -> C3 Vehicles
/// Customers can never choose their role; it is set in Supabase only.
class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final role = await Api.fetchMyRole();
    if (!mounted) return;
    // Later: owners go to O1b Verification code first.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            role == 'owner' ? const OwnerShell() : const VehiclesScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
}
