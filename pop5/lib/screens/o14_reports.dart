import 'package:flutter/material.dart';
import '../services/owner_api.dart';

class O14ReportsScreen extends StatefulWidget {
  const O14ReportsScreen({super.key});

  @override
  State<O14ReportsScreen> createState() => _O14ReportsScreenState();
}

class _O14ReportsScreenState extends State<O14ReportsScreen> {
  static const Color _dark = Color(0xFF262626);
  static const Color _muted = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFD0D0D0);

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _shortMonths = [
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
    'Dec',
  ];

  String _selectedPeriod = 'This month';
  final List<String> _periods = ['This month', 'Last month', 'Custom'];
  DateTimeRange? _customRange;

  OwnerReportsData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  (DateTime, DateTime) _resolveDateRange() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Last month') {
      final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
      final lastOfLastMonth = DateTime(now.year, now.month, 0);
      return (firstOfLastMonth, lastOfLastMonth);
    }
    if (_selectedPeriod == 'Custom' && _customRange != null) {
      return (_customRange!.start, _customRange!.end);
    }
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final today = DateTime(now.year, now.month, now.day);
    return (firstOfThisMonth, today);
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (start, end) = _resolveDateRange();
      final result = await OwnerApi.fetchReportsData(start: start, end: end);
      if (!mounted) return;
      setState(() {
        _data = result;
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

  Future<void> _onSelectPeriod(String period) async {
    if (period == 'Custom') {
      final now = DateTime.now();
      final initialRange = _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 6)),
            end: now,
          );
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: initialRange,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: _dark,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: _dark,
              ),
            ),
            child: child!,
          );
        },
      );
      if (!mounted || picked == null) return;
      setState(() {
        _customRange = picked;
        _selectedPeriod = 'Custom';
      });
      await _loadReports();
      return;
    }

    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    await _loadReports();
  }

  String _periodCardTitle() {
    final now = DateTime.now();
    if (_selectedPeriod == 'Last month') {
      final lastMonth = DateTime(now.year, now.month - 1, 1);
      return 'Revenue · ${_months[lastMonth.month - 1]}';
    }
    if (_selectedPeriod == 'Custom' && _customRange != null) {
      final s = _customRange!.start;
      final e = _customRange!.end;
      return 'Revenue · ${s.day} ${_shortMonths[s.month - 1]} – ${e.day} ${_shortMonths[e.month - 1]}';
    }
    return 'Revenue · ${_months[now.month - 1]}';
  }

  String _formatCurrency(double amount) {
    final bool isWhole = amount == amount.roundToDouble();
    final String raw =
        isWhole ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final parts = raw.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? 'RM $intPart.${parts[1]}' : 'RM $intPart';
  }

  String _rentalsSubtitle(int count) {
    final noun = count == 1 ? 'rental' : 'rentals';
    if (_selectedPeriod == 'Last month') return '$count $noun last month';
    if (_selectedPeriod == 'Custom') return '$count $noun in selected period';
    return '$count $noun this month';
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
      body: RefreshIndicator(
        color: _dark,
        onRefresh: _loadReports,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Pills
              Wrap(
                spacing: 10,
                children: _periods.map((period) {
                  final selected = _selectedPeriod == period;
                  String label = period;
                  if (period == 'Custom' && selected && _customRange != null) {
                    final s = _customRange!.start;
                    final e = _customRange!.end;
                    label =
                        '${s.day} ${_shortMonths[s.month - 1]} – ${e.day} ${_shortMonths[e.month - 1]}';
                  }
                  return GestureDetector(
                    onTap: () => _onSelectPeriod(period),
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
                        label,
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
                          'Failed to load reports:\n$_error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _loadReports,
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: _dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildReportCards(_data!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCards(OwnerReportsData report) {
    final bars = report.dailyBarHeights;
    final peakIndex = report.peakBarIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                _periodCardTitle(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(report.totalRevenue),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _rentalsSubtitle(report.rentalCount),
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(bars.length, (i) {
                    final isPeak = i == peakIndex;
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
              Text(
                report.totalRevenue > 0
                    ? 'Revenue trend across selected period'
                    : 'No completed payments in this period',
                style: const TextStyle(fontSize: 11.5, color: _muted),
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
              if (report.busiestHours.isEmpty)
                const Text(
                  'No rental activity in this period.',
                  style: TextStyle(fontSize: 12.5, color: _muted),
                )
              else
                for (int i = 0; i < report.busiestHours.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildBusyHourRow(
                    report.busiestHours[i].label,
                    report.busiestHours[i].ratio,
                  ),
                ],
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Most-used vehicles',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 12),
              if (report.mostUsedVehicles.isEmpty)
                const Text(
                  'No vehicle rentals in this period.',
                  style: TextStyle(fontSize: 12.5, color: _muted),
                )
              else
                for (int i = 0; i < report.mostUsedVehicles.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.mostUsedVehicles[i].vehicleTitle,
                        style: const TextStyle(fontSize: 13.5, color: _dark),
                      ),
                      Text(
                        '${report.mostUsedVehicles[i].rentalCount} ${report.mostUsedVehicles[i].rentalCount == 1 ? 'rental' : 'rentals'}',
                        style: const TextStyle(fontSize: 13, color: _muted),
                      ),
                    ],
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBusyHourRow(String timeLabel, double ratio) {
    return Row(
      children: [
        SizedBox(
          width: 104,
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
