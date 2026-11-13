import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c3_vehicles.dart';
import 'c7_waiting_for_payment.dart';
import 'c8_receipt.dart';
import 'c9_active_rental.dart';
import 'c9b_rental_ten_min_left.dart';
import 'c9c_rental_overdue.dart';
import 'c13_notifications.dart';
import 'c14_settings.dart';

class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  bool _loading = true;
  String? _error;
  List _current = [];
  List _past = [];
  int _unread = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _current.isNotEmpty) setState(() {});
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final rows = await Supabase.instance.client
          .from('bookings')
          .select('*, vehicles(*)')
          .eq('customer_id', userId)
          .order('created_at', ascending: false);
      final unread = await Api.fetchUnreadCount();
      final currentList = [];
      final pastList = [];

      for (final r in rows) {
        final item = Map.from(r);
        final status = (item['status'] ?? '').toString();
        if (status == 'active' ||
            status == 'paid' ||
            status == 'confirmed' ||
            status == 'pending_payment') {
          currentList.add(item);
        } else if (status == 'completed') {
          pastList.add(item);
        }
      }

      if (!mounted) return;
      setState(() {
        _current = currentList;
        _past = pastList;
        _unread = unread;
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _remainingLabel(String? endIso) {
    if (endIso == null) return 'Active · tracked';
    final end = DateTime.tryParse(endIso);
    if (end == null) return 'Active · tracked';
    final d = end.difference(DateTime.now());
    if (d.isNegative) return 'Overdue · tracked';
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$m left · tracked';
  }

  String _durationLabel(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '$m min';
    return '$h hr $m min';
  }

  String _dateOnly(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _openCurrent(Map<String, dynamic> booking) async {
    final id = booking['id'].toString();
    final status = (booking['status'] ?? '').toString();

    if (status == 'pending_payment') {
      final paid = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => WaitingPaymentScreen(bookingId: id)),
      );
      if (paid == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReceiptScreen(bookingId: id)),
        );
      }
      if (mounted) _load();
      return;
    }

    final end = DateTime.tryParse(booking['end_time'] ?? '');
    final left = end?.difference(DateTime.now()) ?? const Duration(minutes: 30);
    final Widget screen = left.isNegative
        ? RentalOverdueScreen(bookingId: id)
        : left <= const Duration(minutes: 10)
            ? RentalTenMinLeftScreen(bookingId: id)
            : ActiveRentalScreen(bookingId: id);

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  void _openReceipt(String bookingId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReceiptScreen(bookingId: bookingId)),
    );
  }

  void _switchTab(int index) {
    if (index == 1) return;
    final Widget dest = switch (index) {
      0 => const VehiclesScreen(),
      2 => const NotificationsScreen(),
      _ => const SettingsScreen(),
    };
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'My rentals', showBack: false),
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
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 64),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: AppColors.dark),
                        ),
                      )
                    else if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          children: [
                            Text('Could not load rentals.\n$_error',
                                textAlign: TextAlign.center,
                                style: inter(14, color: AppColors.text2)),
                            TextButton(
                              onPressed: _load,
                              child: const Text('Try again'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      Text('Current',
                          style: inter(14, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (_current.isEmpty)
                        _emptyCard('No active or pending rentals.')
                      else
                        _groupedCard(
                          children: _current.map((b) {
                            final vehicleName =
                                b['vehicles']?['name'] ?? 'Vehicle';
                            final isPending = b['status'] == 'pending_payment';
                            final subtitle = isPending
                                ? 'Waiting for payment · pay at counter'
                                : _remainingLabel(b['end_time']?.toString());

                            return _rentalRow(
                              icon: isPending
                                  ? Icons.receipt_long_outlined
                                  : Icons.timer_outlined,
                              title: vehicleName,
                              subtitle: subtitle,
                              buttonLabel: isPending ? 'View' : 'Open',
                              filled: !isPending,
                              onPressed: () => _openCurrent(b),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 20),
                      Text('Past rentals',
                          style: inter(14, weight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      if (_past.isEmpty)
                        _emptyCard('No past rentals yet.')
                      else
                        _groupedCard(
                          children: _past.map((b) {
                            final vehicleName =
                                b['vehicles']?['name'] ?? 'Vehicle';
                            final dateStr =
                                _dateOnly(b['start_time']?.toString());
                            final mins = (b['duration_minutes'] ?? 20) as int;
                            final total = ((b['total_amount'] ?? 0.0) as num)
                                .toStringAsFixed(2);

                            return _rentalRow(
                              icon: Icons.pedal_bike,
                              title: vehicleName,
                              subtitle:
                                  '$dateStr · ${_durationLabel(mins)} · RM $total',
                              buttonLabel: 'Receipt',
                              filled: false,
                              onPressed: () => _openReceipt(b['id'].toString()),
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            _CustomerBottomNav(
              currentIndex: 1,
              unread: _unread,
              onSelect: _switchTab,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Text(text, style: inter(13, color: AppColors.text2)),
    );
  }

  Widget _groupedCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _rentalRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required bool filled,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: inter(15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: inter(12, color: AppColors.text2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 36,
            child: filled
                ? FilledButton(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dark,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(buttonLabel,
                        style: inter(13,
                            weight: FontWeight.w600, color: Colors.white)),
                  )
                : OutlinedButton(
                    onPressed: onPressed,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.dark, width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(buttonLabel,
                        style: inter(13,
                            weight: FontWeight.w600, color: AppColors.ink)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CustomerBottomNav extends StatelessWidget {
  final int currentIndex;
  final int unread;
  final ValueChanged<int> onSelect;

  const _CustomerBottomNav({
    required this.currentIndex,
    required this.unread,
    required this.onSelect,
  });

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
          _item(Icons.pedal_bike, 'Rent', 0),
          _item(Icons.receipt_long_outlined, 'My rentals', 1),
          _item(Icons.notifications_none, 'Notifications', 2, badge: unread),
          _item(Icons.settings_outlined, 'Settings', 3),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, int index, {int badge = 0}) {
    final current = currentIndex == index;
    final color = current ? AppColors.ink : AppColors.hint;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: inter(11,
                      weight: current ? FontWeight.w700 : FontWeight.w400,
                      color: color),
                ),
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
                    color: AppColors.ink,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badge',
                    style:
                        inter(10, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
