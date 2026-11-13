import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'c3_vehicles.dart';
import 'c8_receipt.dart';
import 'c9_active_rental.dart';
import 'c12_my_rentals.dart';
import 'c14_settings.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Not logged in');

      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _items = [
          for (final e in res) Map.from(e),
        ];
      });
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
      });
      showToast(context, 'All notifications marked as read.');
    } catch (e) {
      if (mounted) showToast(context, 'Failed to update notifications: $e');
    }
  }

  Future<void> _onTapItem(Map<String, dynamic> item) async {
    final id = item['id'];
    if (item['is_read'] != true && id != null) {
      setState(() => item['is_read'] = true);
      try {
        await Supabase.instance.client
            .from('notifications')
            .update({'is_read': true}).eq('id', id);
      } catch (_) {}
    }

    final type = (item['type'] ?? '').toString();
    final bookingId = item['booking_id']?.toString();
    if (!mounted || bookingId == null || bookingId.isEmpty) return;

    if (type == 'receipt' || type == 'payment') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReceiptScreen(bookingId: bookingId)),
      );
    } else if (type == 'rental_reminder' || type == 'geofence') {
      Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => ActiveRentalScreen(bookingId: bookingId)),
      );
    }
  }

  IconData _iconFor(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString().toLowerCase();
    final title = (item['title'] ?? '').toString().toLowerCase();

    if (type.contains('payment') || title.contains('payment')) {
      return Icons.check_circle_outline;
    }
    if (type.contains('reminder') ||
        type.contains('timer') ||
        title.contains('minutes')) {
      return Icons.timer_outlined;
    }
    if (type.contains('boundary') ||
        type.contains('geofence') ||
        title.contains('boundary')) {
      return Icons.location_on_outlined;
    }
    if (type.contains('receipt') || title.contains('receipt')) {
      return Icons.receipt_long_outlined;
    }
    if (type.contains('identity') ||
        type.contains('ic') ||
        title.contains('verified')) {
      return Icons.shield_outlined;
    }
    return Icons.notifications_none;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
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

  void _switchTab(int index) {
    if (index == 2) return;
    final Widget dest = switch (index) {
      0 => const VehiclesScreen(),
      1 => const MyRentalsScreen(),
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
    final unreadCount =
        _items.where((n) => (n['is_read'] ?? false) == false).length;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1.5),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Notifications',
                      style: inter(20, weight: FontWeight.w700)),
                  GestureDetector(
                    onTap: unreadCount > 0 ? _markAllRead : null,
                    child: Text(
                      'Mark all read',
                      style: inter(
                        13,
                        weight: FontWeight.w600,
                        color: unreadCount > 0 ? AppColors.ink : AppColors.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.dark),
                      )
                    : _error != null
                        ? ListView(
                            children: [
                              const SizedBox(height: 48),
                              Text('Could not load notifications.\n$_error',
                                  textAlign: TextAlign.center,
                                  style: inter(14, color: AppColors.text2)),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Try again'),
                              ),
                            ],
                          )
                        : _items.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 64),
                                  Text('No notifications yet.',
                                      textAlign: TextAlign.center,
                                      style: inter(14, color: AppColors.text2)),
                                ],
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _items.length,
                                separatorBuilder: (_, __) => const Divider(
                                  height: 1,
                                  thickness: 1.5,
                                  color: AppColors.divider,
                                ),
                                itemBuilder: (_, i) {
                                  final item = _items[i];
                                  final unread = item['is_read'] != true;
                                  return InkWell(
                                    onTap: () => _onTapItem(item),
                                    child: Container(
                                      color: unread
                                          ? AppColors.surface
                                          : Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.border,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              _iconFor(item),
                                              size: 20,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  (item['title'] ?? '')
                                                      .toString(),
                                                  style: inter(14,
                                                      weight: FontWeight.w700),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  (item['body'] ??
                                                          item['message'] ??
                                                          '')
                                                      .toString(),
                                                  style: inter(13,
                                                      color: AppColors.text2),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _timeAgo(item['created_at']
                                                      ?.toString()),
                                                  style: inter(12,
                                                      color: AppColors.hint),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ),
            _NotificationsBottomNav(
              unread: unreadCount,
              onSelect: _switchTab,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsBottomNav extends StatelessWidget {
  final int unread;
  final ValueChanged<int> onSelect;

  const _NotificationsBottomNav({
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
          _item(Icons.notifications, 'Notifications', 2, badge: unread),
          _item(Icons.settings_outlined, 'Settings', 3),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, int index, {int badge = 0}) {
    final current = index == 2;
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
