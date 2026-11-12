import 'package:flutter/material.dart';

class O8AlertsScreen extends StatelessWidget {
  final VoidCallback? onOpenMap;

  const O8AlertsScreen({super.key, this.onOpenMap});

  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    final alerts = [
      _AlertItem(
        title: 'Auto-charge failed',
        time: '2 min ago',
        detail: 'Scooter S02 · card declined · collect RM 10.00 at return',
        actionLabel: 'Collect payment ›',
        isUrgent: true,
        onTap: () => _showAction(context, 'Collect payment for Scooter S02'),
      ),
      _AlertItem(
        title: '3 late charges · not returned',
        time: '12 min ago',
        detail: 'Bicycle B03 · 1 hr late · auto-charging stopped',
        actionLabel: 'Call customer ›',
        isUrgent: true,
        onTap: () =>
            _showAction(context, 'Calling customer for Bicycle B03...'),
      ),
      _AlertItem(
        title: 'Left Kulai Park',
        time: '18 min ago',
        detail: 'Scooter S02 · ahmad_rides is outside the park boundary',
        actionLabel: 'View on map ›',
        isUrgent: true,
        onTap: onOpenMap ?? () => _showAction(context, 'Opening Live map...'),
      ),
      _AlertItem(
        title: 'Overdue rental',
        time: '25 min ago',
        detail: 'Bicycle B04 · walk-in · 10 min late · not tracked',
        actionLabel: 'Call customer ›',
        isUrgent: true,
        onTap: () => _showAction(context, 'Calling walk-in customer...'),
      ),
      _AlertItem(
        title: 'Location signal lost',
        time: '34 min ago',
        detail: 'Bicycle B03 · no location update for 5 min',
        actionLabel: 'View on map ›',
        isUrgent: false,
        onTap: onOpenMap ?? () => _showAction(context, 'Opening Live map...'),
      ),
    ];

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = alerts[index];
          return InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.isUrgent ? _dark : _border,
                  width: item.isUrgent ? 1.5 : 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      Text(
                        item.time,
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.detail,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.actionLabel,
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

  void _showAction(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

class _AlertItem {
  final String title;
  final String time;
  final String detail;
  final String actionLabel;
  final bool isUrgent;
  final VoidCallback onTap;

  _AlertItem({
    required this.title,
    required this.time,
    required this.detail,
    required this.actionLabel,
    required this.isUrgent,
    required this.onTap,
  });
}
