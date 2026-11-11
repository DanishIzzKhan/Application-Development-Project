import 'package:flutter/material.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c1_login.dart';
import 'o3_rentals.dart';

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
  static const _pages = <Widget>[
    _PlaceholderTab(title: 'Home'), // O2 Home
    RentalsScreen(), // O3 Rentals
    _PlaceholderTab(title: 'Live map'), // O7 Live map
    _PlaceholderTab(title: 'Vehicles'), // O9 Vehicles
    _PlaceholderTab(title: 'More', showLogout: true), // O15 More
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
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
      ),
    );
  }
}
