import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// C4 - shown as a bottom sheet over the dimmed vehicle list.
/// Returns the chosen filter, or null if dismissed.
Future<VehicleFilter?> showFilterPanel(
    BuildContext context, VehicleFilter current) {
  return showModalBottomSheet<VehicleFilter>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _FilterPanel(initial: current),
  );
}

class _FilterPanel extends StatefulWidget {
  final VehicleFilter initial;
  const _FilterPanel({required this.initial});

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late VehicleFilter _f = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter', style: inter(20, weight: FontWeight.w700)),
                GestureDetector(
                  onTap: () => setState(() => _f = const VehicleFilter()),
                  child: Text('Reset', style: inter(14, weight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Vehicle type', style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('All', _f.type == null,
                    () => setState(() => _f = _f.copyWith(clearType: true))),
                _chip('Bicycles', _f.type == 'bicycle',
                    () => setState(() => _f = _f.copyWith(type: 'bicycle'))),
                _chip('Scooters', _f.type == 'scooter',
                    () => setState(() => _f = _f.copyWith(type: 'scooter'))),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Show available now only', style: inter(14)),
                Switch(
                  value: _f.availableOnly,
                  onChanged: (v) =>
                      setState(() => _f = _f.copyWith(availableOnly: v)),
                  activeTrackColor: AppColors.dark,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white,
                  inactiveThumbColor: AppColors.border,
                  trackOutlineColor: WidgetStateProperty.all(AppColors.dark),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Sort by', style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            _radio('Lowest price first', _f.sort == VehicleSort.lowestPrice,
                () => setState(() => _f = _f.copyWith(sort: VehicleSort.lowestPrice))),
            const SizedBox(height: 14),
            _radio('Vehicle name', _f.sort == VehicleSort.name,
                () => setState(() => _f = _f.copyWith(sort: VehicleSort.name))),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Show results',
              onPressed: () => Navigator.pop(context, _f),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Text(
          label,
          style: inter(14,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }

  Widget _radio(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 22,
            color: selected ? AppColors.dark : AppColors.border,
          ),
          const SizedBox(width: 10),
          Text(label,
              style: inter(14,
                  weight: selected ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}