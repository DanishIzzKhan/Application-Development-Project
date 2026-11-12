import 'package:flutter/material.dart';

class O2HomeScreen extends StatelessWidget {
  final VoidCallback? onOpenAlerts;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenMaintenance;

  const O2HomeScreen({
    super.key,
    this.onOpenAlerts,
    this.onOpenSettings,
    this.onOpenReports,
    this.onOpenMaintenance,
  });

  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    final List<double> barHeights = [
      24,
      38,
      30,
      52,
      44,
      62,
      36,
      30,
      56,
      42,
      48,
      68,
      36,
      42,
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Today',
          style: TextStyle(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none,
                    color: _dark, size: 26),
                onPressed: onOpenAlerts ??
                    () => _showStub(context, 'Alerts screen (O8)'),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: _dark,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: _dark, size: 24),
            onPressed: onOpenSettings ??
                () => _showStub(context, 'Settings screen (O16)'),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // 2x2 Status KPI Grid
            Row(
              children: [
                Expanded(child: _buildStatCard('8', 'Available')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('4', 'On rental')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatCard('2', 'Waiting for payment')),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('1', 'Under repair')),
              ],
            ),
            const SizedBox(height: 14),

            // Revenue Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Revenue · this month',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _dark,
                        ),
                      ),
                      GestureDetector(
                        onTap: onOpenReports ??
                            () => _showStub(context, 'Reports screen (O14)'),
                        child: const Text(
                          'View reports ›',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'RM 1,420',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Today: RM 180',
                    style: TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(barHeights.length, (index) {
                        final isToday = index == 11;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            height: barHeights[index],
                            decoration: BoxDecoration(
                              color: isToday ? _dark : const Color(0xFFBDBDBD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Geofence Alert Banner
            InkWell(
              onTap: onOpenAlerts ??
                  () => _showStub(context, 'Alerts screen (O8)'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _dark, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _dark, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 13, color: _dark),
                          children: [
                            TextSpan(
                              text: 'Scooter S02 left Kulai Park. ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                              text: '+2 more alerts',
                              style: TextStyle(color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // AI Maintenance Banner
            InkWell(
              onTap: onOpenMaintenance ??
                  () => _showStub(context, 'AI maintenance screen (O12)'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.build_outlined, color: _dark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 13, color: _dark),
                          children: [
                            TextSpan(
                              text: 'AI: ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(
                                text: '2 vehicles should be inspected soon'),
                          ],
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _muted, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showStub(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), duration: const Duration(seconds: 1)),
    );
  }
}
