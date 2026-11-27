import 'package:flutter/material.dart';
import '../services/owner_api.dart';

class O2HomeScreen extends StatefulWidget {
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

  @override
  State<O2HomeScreen> createState() => _O2HomeScreenState();
}

class _O2HomeScreenState extends State<O2HomeScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  OwnerDashboardData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final res = await OwnerApi.fetchDashboardData();
      if (!mounted) return;
      setState(() {
        _data = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dashboard: $e')),
      );
    }
  }

  String _formatRm(double value) {
    final isWhole = value == value.roundToDouble();
    final raw = isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
    final parts = raw.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? 'RM $intPart.${parts[1]}' : 'RM $intPart';
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final unreadCount = d?.unreadAlertCount ?? 0;
    final available = d != null ? '${d.availableCount}' : '-';
    final onRental = d != null ? '${d.onRentalCount}' : '-';
    final waitingPayment = d != null ? '${d.waitingPaymentCount}' : '-';
    final underRepair = d != null ? '${d.underRepairCount}' : '-';
    final monthRev = d != null ? _formatRm(d.monthRevenue) : 'RM 0';
    final todayRev = d != null ? _formatRm(d.todayRevenue) : 'RM 0';
    final barHeights = d?.dailyBarHeights ?? List<double>.filled(14, 14.0);
    final alertTitle = d?.latestAlertTitle ?? 'All clear';
    final aiCount = d?.aiMaintenanceCount ?? 0;

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
                onPressed: () {
                  if (widget.onOpenAlerts != null) {
                    widget.onOpenAlerts!();
                  } else {
                    _showStub(context, 'Alerts screen (O8)');
                  }
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: _dark,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
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
            onPressed: () {
              if (widget.onOpenSettings != null) {
                widget.onOpenSettings!();
              } else {
                _showStub(context, 'Settings screen (O16)');
              }
            },
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator(color: _dark))
          : RefreshIndicator(
              color: _dark,
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    // 2x2 Status KPI Grid
                    Row(
                      children: [
                        Expanded(child: _buildStatCard(available, 'Available')),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard(onRental, 'On rental')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                              waitingPayment, 'Waiting for payment'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _buildStatCard(underRepair, 'Under repair')),
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
                                onTap: widget.onOpenReports ??
                                    () => _showStub(
                                        context, 'Reports screen (O14)'),
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
                          Text(
                            monthRev,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: _dark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Today: $todayRev',
                            style: const TextStyle(fontSize: 12, color: _muted),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 70,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children:
                                  List.generate(barHeights.length, (index) {
                                final isToday = index == barHeights.length - 1;
                                return Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2.5),
                                    height: barHeights[index],
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? _dark
                                          : const Color(0xFFBDBDBD),
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

                    // Urgent / Geofence Alert Banner
                    InkWell(
                      onTap: widget.onOpenAlerts ??
                          () => _showStub(context, 'Alerts screen (O8)'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: unreadCount > 0 ? _dark : _border,
                            width: unreadCount > 0 ? 1.5 : 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              unreadCount > 0
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: _dark,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13, color: _dark),
                                  children: [
                                    TextSpan(
                                      text: '$alertTitle. ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(
                                      text: unreadCount > 1
                                          ? '+${unreadCount - 1} more alerts'
                                          : (unreadCount == 1
                                              ? 'Tap to review'
                                              : 'No unread alerts'),
                                      style: const TextStyle(color: _muted),
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
                      onTap: widget.onOpenMaintenance ??
                          () =>
                              _showStub(context, 'AI maintenance screen (O12)'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.build_outlined,
                                color: _dark, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                      fontSize: 13, color: _dark),
                                  children: [
                                    const TextSpan(
                                      text: 'AI: ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    TextSpan(
                                      text: aiCount == 1
                                          ? '1 vehicle should be inspected soon'
                                          : '$aiCount vehicles should be inspected soon',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: _muted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
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
