import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c1_login.dart';
import 'o3_rentals.dart';
import 'o9_vehicles.dart';
import 'o2_home.dart';
import 'o7_live_map.dart';
import 'o8_alerts.dart';
import 'o9_vehicles.dart';
import 'o11_payments.dart';
import 'o12_ai_maintenance.dart';
import 'o14_reports.dart';
import 'o15_more.dart';
import 'o16_settings.dart';

/// Owner app frame: shows one tab at a time and the bottom bar from the
/// Figma wireframe (Home · Rentals · Map · Vehicles · More).
///
/// Only Rentals (O3) is built so far. The other tabs are placeholders until
/// their owners build them: O2 Home, O7 Live map, O9 Vehicles, O15 More.
class OwnerShell extends StatefulWidget {
  /// Which tab to open first. 1 = Rentals.
  final int initialTab;
  const OwnerShell({super.key, this.initialTab = 1});

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  late int _tab = widget.initialTab;

  // IndexedStack keeps every tab alive, so switching tabs and coming back
  // does not reset the Rentals list.

  @override
  Widget build(BuildContext context) {
    void pushPage(Widget page) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    }

    final pages = <Widget>[
      O2HomeScreen(
        onOpenAlerts: () => pushPage(
          O8AlertsScreen(
            onOpenMap: () {
              Navigator.pop(context);
              setState(() => _tab = 2);
            },
          ),
        ),
        onOpenSettings: () => pushPage(const O16SettingsScreen()),
        onOpenReports: () => pushPage(const O14ReportsScreen()),
        onOpenMaintenance: () => pushPage(const O12AiMaintenanceScreen()),
      ),
      const RentalsScreen(), // O3 Rentals
      const O7LiveMapScreen(), // O7 Live map
      const O9VehiclesScreen(), // O9 Vehicles
      O15MoreScreen(
        onOpenPayments: () => pushPage(const O11PaymentsScreen()),
        onOpenMaintenance: () => pushPage(const O12AiMaintenanceScreen()),
        onOpenAlerts: () => pushPage(
          O8AlertsScreen(
            onOpenMap: () {
              Navigator.pop(context);
              setState(() => _tab = 2);
            },
          ),
        ),
        onOpenReports: () => pushPage(const O14ReportsScreen()),
        onOpenSettings: () => pushPage(const O16SettingsScreen()),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: SafeArea(
        child: _OwnerBottomNav(
          current: _tab,
          onTap: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

/// 64-high bar with a top divider. Current tab = dark icon + bold label.
class _OwnerBottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _OwnerBottomNav({required this.current, required this.onTap});

  static const _items = [
    (Icons.home_outlined, 'Home'),
    (Icons.assignment_outlined, 'Rentals'),
    (Icons.location_on_outlined, 'Map'),
    (Icons.pedal_bike, 'Vehicles'),
    (Icons.more_horiz, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1.5)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            _item(_items[i].$1, _items[i].$2, i == current, () => onTap(i)),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, bool selected, VoidCallback tap) {
    final color = selected ? AppColors.ink : AppColors.hint;
    return Expanded(
      child: InkWell(
        onTap: tap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: inter(11,
                    weight: selected ? FontWeight.w700 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

/// Simple page for tabs that are not built yet.
class _PlaceholderTab extends StatelessWidget {
  final String title;

  /// Temporary "Log out" button (on More) until O15/O16 are built.
  final bool showLogout;

  const _PlaceholderTab({required this.title, this.showLogout = false});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log out?', style: inter(18, weight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: inter(14, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Log out', style: inter(14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await Api.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: title, showBack: false),
      body: Center(
<<<<<<< HEAD
        child: Text('Coming soon', style: inter(15, color: AppColors.hint)),
=======
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Coming soon', style: inter(15, color: AppColors.hint)),
            if (showLogout) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout, color: AppColors.dark),
                label: Text('Log out',
                    style: inter(14,
                        weight: FontWeight.w600, color: AppColors.dark)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.dark, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ],
        ),
>>>>>>> 3d57ee7487b25fa5a4d1d6f6fd0f48972ab01925
      ),
    );
  }
}
