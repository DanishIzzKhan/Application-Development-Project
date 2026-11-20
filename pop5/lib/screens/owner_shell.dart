import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import 'c1_login.dart';
import 'o3_rentals.dart';
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
/// Tabs: O2 Home, O3 Rentals, O7 Live map, O9 Vehicles, O15 More.
/// Log out (O15 More and O16 Settings) is handled here, so both behave the same.
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

  /// Asks first, signs out of Supabase, then shows the login screen with
  /// every owner screen removed (Back can't return to the owner app).
  Future<void> _logout() async {
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
    if (ok != true || !mounted) return;
    try {
      await Api.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e'); // still leave the owner app
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

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
        onOpenSettings: () => pushPage(O16SettingsScreen(onLogout: _logout)),
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
        onOpenSettings: () => pushPage(O16SettingsScreen(onLogout: _logout)),
        onLogout: _logout,
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
