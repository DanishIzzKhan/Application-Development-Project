import 'package:flutter/material.dart';
import '../services/owner_api.dart';
import 'o13_service_history.dart';

class O12AiMaintenanceScreen extends StatefulWidget {
  const O12AiMaintenanceScreen({super.key});

  @override
  State<O12AiMaintenanceScreen> createState() => _O12AiMaintenanceScreenState();
}

class _O12AiMaintenanceScreenState extends State<O12AiMaintenanceScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  List<MaintenancePriorityItem> _items = [];
  bool _loading = true;
  bool _analyzing = false;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _loadPriorities();
  }

  Future<void> _loadPriorities({bool isReanalyze = false}) async {
    setState(() {
      if (isReanalyze) {
        _analyzing = true;
      } else {
        _loading = true;
      }
      _error = null;
    });

    try {
      final list = await OwnerApi.fetchAiMaintenancePriorities(
        syncPredictions: true,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _analyzing = false;
      });
      if (isReanalyze) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI maintenance priorities updated'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _analyzing = false;
      });
    }
  }

  Future<void> _openServiceHistory(
    MaintenancePriorityItem item, {
    bool? forceUnderRepair,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => O13ServiceHistoryScreen(
          vehicleId: item.vehicleId,
          vehicleName: item.vehicleTitle,
          initialUnderRepair: forceUnderRepair ?? item.isUnderRepair,
        ),
      ),
    );
    if (!mounted) return;
    _loadPriorities();
  }

  Future<void> _handleMarkUnderRepair(MaintenancePriorityItem item) async {
    if (_busyIds.contains(item.vehicleId)) return;
    setState(() => _busyIds.add(item.vehicleId));
    try {
      await OwnerApi.markVehicleUnderRepair(item.vehicleId);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((e) => e.vehicleId == item.vehicleId
                ? e.copyWith(isUnderRepair: true)
                : e)
            .toList();
      });
      await _openServiceHistory(item, forceUnderRepair: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(item.vehicleId));
      }
    }
  }

  Future<void> _handleToggleInspected(MaintenancePriorityItem item) async {
    if (_busyIds.contains(item.vehicleId)) return;
    final nextInspected = !item.isInspected;
    setState(() => _busyIds.add(item.vehicleId));
    try {
      await OwnerApi.toggleVehicleInspected(item.vehicleId, nextInspected);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map((e) => e.vehicleId == item.vehicleId
                ? e.copyWith(isInspected: nextInspected)
                : e)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextInspected
                ? '${item.vehicleTitle} marked as inspected'
                : 'Inspection status reset',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update inspection: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(item.vehicleId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'AI maintenance',
          style: TextStyle(
            color: _dark,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Re-run AI analysis',
            onPressed: (_loading || _analyzing)
                ? null
                : () => _loadPriorities(isReanalyze: true),
            icon: _analyzing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _dark,
                    ),
                  )
                : const Icon(Icons.refresh, color: _dark),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: RefreshIndicator(
        color: _dark,
        onRefresh: () => _loadPriorities(isReanalyze: true),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vehicles ranked by how likely they need maintenance, based on usage since the last service.',
                style: TextStyle(
                  fontSize: 13,
                  color: _muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 120),
                  child: Center(
                    child: CircularProgressIndicator(color: _dark),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Failed to load AI maintenance:\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _loadPriorities(),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: _dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(
                    child: Text(
                      'No active vehicles found.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  ),
                )
              else
                for (int i = 0; i < _items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _buildPriorityCard(i + 1, _items[i]),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityCard(int rank, MaintenancePriorityItem item) {
    final bool isHigh = item.priority == 'HIGH';
    final bool isMedium = item.priority == 'MEDIUM';
    final bool isBusy = _busyIds.contains(item.vehicleId);

    final Color barColor = isHigh
        ? _dark
        : (isMedium ? const Color(0xFF4F4F4F) : const Color(0xFF8C8C8C));

    Widget? actionButton;
    if (isHigh) {
      actionButton = SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: isBusy ? null : () => _handleMarkUnderRepair(item),
          style: ElevatedButton.styleFrom(
            backgroundColor: _dark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            item.isUnderRepair
                ? 'Marked as under repair'
                : 'Mark as under repair',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } else if (isMedium) {
      actionButton = SizedBox(
        width: double.infinity,
        height: 44,
        child: OutlinedButton(
          onPressed: isBusy ? null : () => _handleToggleInspected(item),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _dark, width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            item.isInspected ? 'Inspected ✓' : 'Mark as inspected',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
      );
    }

    return _buildMaintenanceCard(
      rankTitle: '$rank. ${item.vehicleTitle}',
      badge: item.priority,
      badgeFilled: isHigh,
      progress: item.riskScore,
      barColor: barColor,
      description: item.description,
      hasThickBorder: isHigh,
      onCardTap: () => _openServiceHistory(item),
      button: actionButton,
    );
  }

  Widget _buildMaintenanceCard({
    required String rankTitle,
    required String badge,
    required bool badgeFilled,
    required double progress,
    required Color barColor,
    required String description,
    required bool hasThickBorder,
    required VoidCallback onCardTap,
    Widget? button,
  }) {
    return InkWell(
      onTap: onCardTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasThickBorder ? _dark : _border,
            width: hasThickBorder ? 1.5 : 1.2,
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
                    rankTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeFilled ? _dark : Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _dark, width: 1.2),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeFilled ? Colors.white : _dark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE6E6E6),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12.5,
                color: _muted,
                height: 1.35,
              ),
            ),
            if (button != null) ...[
              const SizedBox(height: 14),
              button,
            ],
          ],
        ),
      ),
    );
  }
}
