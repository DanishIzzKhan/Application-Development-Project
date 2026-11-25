import 'package:flutter/material.dart';
import '../services/api.dart';

class O8AlertsScreen extends StatefulWidget {
  final VoidCallback? onOpenMap;

  const O8AlertsScreen({super.key, this.onOpenMap});

  @override
  State<O8AlertsScreen> createState() => _O8AlertsScreenState();
}

class _O8AlertsScreenState extends State<O8AlertsScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);
  static const Color _successGreen = Color(0xFF1E7E34);

  List<dynamic> _alerts = [];
  bool _loading = true;
  String? _error;
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    final messenger = _messenger;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger?.hideCurrentSnackBar();
    });
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.fetchOwnerAlerts();
      if (!mounted) return;
      setState(() {
        _alerts = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _handleTapAlert(Map row) async {
    final id = row['id']?.toString();
    if (id != null && row['read_at'] == null) {
      setState(() {
        row['read_at'] = DateTime.now().toIso8601String();
      });
      await Api.markNotificationRead(id);
    }

    if (!mounted) return;
    final type = (row['type'] ?? '').toString().toLowerCase();
    final title = (row['title'] ?? 'Alert').toString();

    if (type.contains('geo') ||
        type.contains('map') ||
        type.contains('location')) {
      if (widget.onOpenMap != null) {
        widget.onOpenMap!();
      } else {
        _showAction('Opening Live map...');
      }
    } else if (type.contains('payment') || type.contains('charge')) {
      _showAction('Opening payment details for: $title');
    } else {
      _showAction(title);
    }
  }

  Future<void> _markAllRead() async {
    final unreadIds = _alerts
        .where((a) => a is Map && a['read_at'] == null && a['id'] != null)
        .map((a) => (a as Map)['id'].toString())
        .toList();

    if (unreadIds.isEmpty) return;

    setState(() {
      final now = DateTime.now().toIso8601String();
      for (final a in _alerts) {
        if (a is Map) a['read_at'] ??= now;
      }
    });
    await Api.markAllNotificationsRead();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _successGreen,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'All alerts marked as read',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () async {
            if (!mounted) return;
            setState(() {
              for (final a in _alerts) {
                if (a is Map && unreadIds.contains(a['id']?.toString())) {
                  a['read_at'] = null;
                }
              }
            });
            await Api.markNotificationsUnread(unreadIds);
          },
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      controller.close();
    });
  }

  String _formatTimeAgo(dynamic rawTime) {
    if (rawTime == null) return '';
    final dt = DateTime.tryParse(rawTime.toString())?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  String _actionText(Map row) {
    final type = (row['type'] ?? '').toString().toLowerCase();
    if (type.contains('geo') ||
        type.contains('map') ||
        type.contains('location')) {
      return 'View on map ›';
    }
    if (type.contains('payment') || type.contains('charge')) {
      return 'Collect payment ›';
    }
    if (type.contains('late') || type.contains('overdue')) {
      return 'Call customer ›';
    }
    return 'View details ›';
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _alerts.any((a) => a is Map && a['read_at'] == null);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: _dark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: _dark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _dark));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load alerts:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loadAlerts,
                child: const Text('Retry', style: TextStyle(color: _dark)),
              ),
            ],
          ),
        ),
      );
    }

    if (_alerts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAlerts,
        child: ListView(
          children: const [
            SizedBox(height: 160),
            Center(
              child: Text(
                'No alerts right now.',
                style: TextStyle(color: _muted, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final row = Map<String, dynamic>.from(_alerts[index] as Map);
          final isUnread = row['read_at'] == null;
          final isUrgent = row['is_urgent'] == true || isUnread;
          final title = (row['title'] ?? 'Alert').toString();
          final detail = (row['body'] ?? row['message'] ?? '').toString();
          final timeLabel = _formatTimeAgo(row['created_at']);

          return InkWell(
            onTap: () => _handleTapAlert(_alerts[index] as Map),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUnread ? const Color(0xFFFAFAFA) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isUrgent ? _dark : _border,
                  width: isUrgent ? 1.5 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: _dark,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: _muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _actionText(row),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAction(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _successGreen,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
