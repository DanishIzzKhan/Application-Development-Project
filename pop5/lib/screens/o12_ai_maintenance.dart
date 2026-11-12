import 'package:flutter/material.dart';
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

  bool _b03UnderRepair = false;
  bool _s01Inspected = false;

  void _openServiceHistory(String vehicleName, {bool initialRepair = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => O13ServiceHistoryScreen(
          vehicleName: vehicleName,
          initialUnderRepair: initialRepair,
        ),
      ),
    );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEAEA)),
        ),
      ),
      body: SingleChildScrollView(
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

            // 1. HIGH priority card
            _buildMaintenanceCard(
              rankTitle: '1. Bicycle B03',
              badge: 'HIGH',
              badgeFilled: true,
              progress: 0.85,
              barColor: _dark,
              description:
                  '48 km and 19 rentals since last service · 1 issue reported',
              hasThickBorder: true,
              onCardTap: () =>
                  _openServiceHistory('Bicycle B03', initialRepair: true),
              button: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _b03UnderRepair = true);
                    _openServiceHistory('Bicycle B03', initialRepair: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _b03UnderRepair
                        ? 'Marked as under repair'
                        : 'Mark as under repair',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. MEDIUM priority card
            _buildMaintenanceCard(
              rankTitle: '2. Scooter S01',
              badge: 'MEDIUM',
              badgeFilled: false,
              progress: 0.54,
              barColor: const Color(0xFF4F4F4F),
              description:
                  '24 ride hours since last service · serviced 18 days ago',
              hasThickBorder: false,
              onCardTap: () => _openServiceHistory('Scooter S01'),
              button: SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _s01Inspected = !_s01Inspected);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _s01Inspected
                              ? 'Scooter S01 marked as inspected'
                              : 'Inspection status reset',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _dark, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _s01Inspected ? 'Inspected ✓' : 'Mark as inspected',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 3. LOW priority card
            _buildMaintenanceCard(
              rankTitle: '3. Bicycle B01',
              badge: 'LOW',
              badgeFilled: false,
              progress: 0.20,
              barColor: const Color(0xFF8C8C8C),
              description: 'Recently serviced · low usage',
              hasThickBorder: false,
              onCardTap: () => _openServiceHistory('Bicycle B01'),
            ),
          ],
        ),
      ),
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
                Text(
                  rankTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
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
