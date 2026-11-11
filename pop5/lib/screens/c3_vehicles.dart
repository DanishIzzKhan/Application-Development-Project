import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c4_filter_panel.dart';
import 'c5_book_vehicle.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  VehicleFilter _filter = const VehicleFilter();
  List<Vehicle> _vehicles = [];
  ({String vehicle, DateTime end})? _active;
  int _unread = 0;
  bool _loading = true;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    // keeps the "0:42 left" banner fresh
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _active != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.fetchVehicles(_filter),
        Api.fetchActiveRental(),
        Api.fetchUnreadCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicles = results[0] as List<Vehicle>;
        _active = results[1] as ({String vehicle, DateTime end})?;
        _unread = results[2] as int;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openFilter() async {
    final result = await showFilterPanel(context, _filter);
    if (result == null) return;
    _filter = result;
    _load();
  }

  Future<void> _book(Vehicle v) async {
    final booked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BookVehicleScreen(vehicle: v)),
    );
    if (booked == true) _load();
  }

  String _remaining(DateTime end) {
    final d = end.difference(DateTime.now());
    if (d.isNegative) return 'Overdue';
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m left';
  }

  void _soon(String screen) =>
      showToast(context, '$screen is not built yet.');

  @override
  Widget build(BuildContext context) {
    final availableCount = _vehicles.where((v) => v.isAvailable).length;

    return Scaffold(
      appBar: const AppHeader(title: 'Rent a vehicle', showBack: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_active != null) ...[
                      GestureDetector(
                        onTap: () => _soon('Active rental (C9)'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.ink,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Rental in progress · ${_active!.vehicle}',
                                  overflow: TextOverflow.ellipsis,
                                  style: inter(14,
                                      weight: FontWeight.w600,
                                      color: Colors.white),
                                ),
                              ),
                              Text('${_remaining(_active!.end)} ›',
                                  style: inter(14,
                                      weight: FontWeight.w700,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$availableCount available now',
                            style: inter(14, color: AppColors.text2)),
                        GestureDetector(
                          onTap: _openFilter,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.dark, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt_outlined, size: 18),
                                const SizedBox(width: 6),
                                Text(_filter.typeLabel,
                                    style: inter(14, weight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Text('Could not load vehicles.\n$_error',
                                textAlign: TextAlign.center,
                                style: inter(14, color: AppColors.text2)),
                            TextButton(
                                onPressed: _load, child: const Text('Try again')),
                          ],
                        ),
                      )
                    else if (_vehicles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: Text('No vehicles match your filter.',
                            textAlign: TextAlign.center,
                            style: inter(14, color: AppColors.text2)),
                      )
                    else
                      for (final v in _vehicles) ...[
                        _VehicleCard(vehicle: v, onBook: () => _book(v)),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
            _BottomNav(onSoon: _soon, unread: _unread),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onBook;
  const _VehicleCard({required this.vehicle, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Row(
        children: [
          v.photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(v.photoUrl!,
                      width: 64, height: 64, fit: BoxFit.cover),
                )
              : DashedBox(
                  width: 64,
                  height: 64,
                  child: Text('PHOTO',
                      style: inter(12, color: AppColors.text2)),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.name, style: inter(16, weight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${v.typeLabel} · ${v.priceLabel} / 20 min',
                    style: inter(13, color: AppColors.text2)),
                const SizedBox(height: 4),
                Text(v.statusLabel,
                    style: inter(12,
                        weight: FontWeight.w600, color: AppColors.dark)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: v.isAvailable ? onBook : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Book',
                  style: inter(14, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final void Function(String) onSoon;
  final int unread;
  const _BottomNav({required this.onSoon, required this.unread});

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
          _item(Icons.pedal_bike, 'Rent', true, null),
          _item(Icons.receipt_long_outlined, 'My rentals', false,
              () => onSoon('My rentals (C12)')),
          _item(Icons.notifications_none, 'Notifications', false,
              () => onSoon('Notifications (C13)'),
              badge: unread),
          _item(Icons.settings_outlined, 'Settings', false,
              () => onSoon('Settings (C14)')),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, bool current, VoidCallback? onTap,
      {int badge = 0}) {
    final color = current ? AppColors.ink : AppColors.hint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(label,
                    style: inter(11,
                        weight: current ? FontWeight.w700 : FontWeight.w400,
                        color: color)),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                left: 53,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  child: Text('$badge',
                      style: inter(10,
                          weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}