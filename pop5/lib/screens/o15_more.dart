import 'package:flutter/material.dart';

class O15MoreScreen extends StatelessWidget {
  final VoidCallback? onOpenPayments;
  final VoidCallback? onOpenMaintenance;
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onLogout;

  const O15MoreScreen({
    super.key,
    this.onOpenPayments,
    this.onOpenMaintenance,
    this.onOpenAlerts,
    this.onOpenReports,
    this.onOpenSettings,
    this.onLogout,
  });

  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    final items = [
      _MoreItem(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payments',
        subtitle: 'All payments and cash records',
        onTap: onOpenPayments ?? () => _stub(context, 'Payments (O11)'),
      ),
      _MoreItem(
        icon: Icons.build_outlined,
        title: 'AI maintenance',
        subtitle: 'Vehicles to inspect',
        onTap:
            onOpenMaintenance ?? () => _stub(context, 'AI maintenance (O12)'),
      ),
      _MoreItem(
        icon: Icons.notifications_none,
        title: 'Alerts',
        subtitle: 'Out-of-park, overdue, lost signal',
        onTap: onOpenAlerts ?? () => _stub(context, 'Alerts (O8)'),
      ),
      _MoreItem(
        icon: Icons.bar_chart_rounded,
        title: 'Reports',
        subtitle: 'Monthly revenue and usage',
        onTap: onOpenReports ?? () => _stub(context, 'Reports (O14)'),
      ),
      _MoreItem(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'Shop, pricing rules and notifications',
        onTap: onOpenSettings ?? () => _stub(context, 'Settings (O16)'),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'More',
          style: TextStyle(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _border),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? const Radius.circular(12) : Radius.zero,
                      bottom: index == items.length - 1
                          ? const Radius.circular(12)
                          : Radius.zero,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, color: _dark, size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: _muted, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout, color: _dark, size: 18),
                  label: const Text(
                    'Log out',
                    style: TextStyle(
                      color: _dark,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _stub(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }
}

class _MoreItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _MoreItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
