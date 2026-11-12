import 'package:flutter/material.dart';

class O14ReportsScreen extends StatefulWidget {
  const O14ReportsScreen({super.key});

  @override
  State<O14ReportsScreen> createState() => _O14ReportsScreenState();
}

class _O14ReportsScreenState extends State<O14ReportsScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  String _selectedPeriod = 'This month';
  final List<String> _periods = ['This month', 'Last month', 'Custom'];

  @override
  Widget build(BuildContext context) {
    final bool isLastMonth = _selectedPeriod == 'Last month';
    final String monthTitle =
        isLastMonth ? 'Revenue · October' : 'Revenue · November';
    final String revenueText = isLastMonth ? 'RM 2,180' : 'RM 1,420';
    final String rentalsText =
        isLastMonth ? '176 rentals last month' : '118 rentals this month';

    final List<double> bars = isLastMonth
        ? [34, 46, 54, 40, 62, 52, 68, 56, 48, 60, 44, 58, 50, 64]
        : [28, 42, 34, 58, 46, 34, 52, 68, 40, 46, 32, 56, 40, 52];

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
          'Reports',
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Pills
            Wrap(
              spacing: 10,
              children: _periods.map((period) {
                final selected = _selectedPeriod == period;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPeriod = period),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? _dark : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected ? _dark : _border,
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      period,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : _dark,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Revenue Bar Chart Card
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
                  Text(
                    monthTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    revenueText,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rentalsText,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 70,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(bars.length, (i) {
                        final isPeak = i == 7;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2.5),
                            height: bars[i],
                            decoration: BoxDecoration(
                              color: isPeak ? _dark : const Color(0xFFBDBDBD),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Revenue by day (illustrative)',
                    style: TextStyle(fontSize: 11.5, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Busiest hours Card
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
                  const Text(
                    'Busiest hours',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildBusyHourRow('4 PM – 6 PM', 0.82),
                  const SizedBox(height: 12),
                  _buildBusyHourRow('10 AM – 12 PM', 0.62),
                  const SizedBox(height: 12),
                  _buildBusyHourRow('6 PM – 8 PM', 0.42),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Most-used vehicles Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border, width: 1.2),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Most-used vehicles',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bicycle B03',
                        style: TextStyle(fontSize: 13.5, color: _dark),
                      ),
                      Text(
                        '34 rentals',
                        style: TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scooter S02',
                        style: TextStyle(fontSize: 13.5, color: _dark),
                      ),
                      Text(
                        '29 rentals',
                        style: TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusyHourRow(String timeLabel, double ratio) {
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            timeLabel,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE6E6E6),
              valueColor: const AlwaysStoppedAnimation<Color>(_dark),
            ),
          ),
        ),
      ],
    );
  }
}
