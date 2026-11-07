import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
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
    _PlaceholderTab(title: 'Home', screen: 'O2 Home'),
    RentalsScreen(),
    _PlaceholderTab(title: 'Live map', screen: 'O7 Live map'),
    _PlaceholderTab(title: 'Vehicles', screen: 'O9 Vehicles'),
    _PlaceholderTab(title: 'More', screen: 'O15 More'),
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
  final String screen;
  const _PlaceholderTab({required this.title, required this.screen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: title, showBack: false),
      body: Center(
        child: Text('$screen: coming soon',
            style: inter(15, color: AppColors.hint)),
      ),
    );
  }
}
