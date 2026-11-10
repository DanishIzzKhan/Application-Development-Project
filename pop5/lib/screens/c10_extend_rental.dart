import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ExtendRentalScreen extends StatefulWidget {
  final String bookingId;
  const ExtendRentalScreen({super.key, required this.bookingId});

  @override
  State<ExtendRentalScreen> createState() => _ExtendRentalScreenState();
}

class _ExtendRentalScreenState extends State<ExtendRentalScreen> {
  bool _loading = true;
  bool _submitting = false;
  Map<String, dynamic>? _rentalData;
  String? _error;
  int _selectedExtraMinutes = 30;

  final List<int> _extensionOptions = [30, 60, 120];

  @override
  void initState() {
    super.initState();
    _fetchRentalDetails();
  }

  Future<void> _fetchRentalDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('bookings')
          .select('*, vehicles(*)')
          .eq('id', widget.bookingId)
          .single();
      if (mounted) {
        setState(() {
          _rentalData = response;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmExtension() async {
    setState(() => _submitting = true);
    try {
      final currentEndTimeStr = _rentalData?['end_time'];
      if (currentEndTimeStr == null) throw Exception('End time not found');

      final currentEndTime = DateTime.parse(currentEndTimeStr);
      final newEndTime = currentEndTime.add(Duration(minutes: _selectedExtraMinutes));

      final extraCost = _selectedExtraMinutes == 30 ? 3.00 : (_selectedExtraMinutes == 60 ? 5.00 : 9.00);
      final currentTotal = (_rentalData?['total_amount'] ?? 0.0) as num;
      final newTotal = currentTotal.toDouble() + extraCost;

      await Supabase.instance.client.from('bookings').update({
        'end_time': newEndTime.toIso8601String(),
        'duration_minutes': (_rentalData?['duration_minutes'] ?? 60) + _selectedExtraMinutes,
        'total_amount': newTotal,
      }).eq('id', widget.bookingId);

      if (!mounted) return;
      showToast(context, 'Rental extended successfully by $_selectedExtraMinutes mins!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to extend rental: $e');
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = _rentalData?['vehicles']?['name'] ?? 'Vehicle';

    return Scaffold(
      appBar: const AppHeader(title: 'Extend Rental (C10)'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.dark))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Could not load booking info.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _fetchRentalDetails,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text('Extend Your Time',
                            style: inter(20, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Select extra duration for $vehicleName',
                            style: inter(14, color: AppColors.text2)),
                        const SizedBox(height: 24),
                        ..._extensionOptions.map((mins) {
                          final isSelected = _selectedExtraMinutes == mins;
                          final price = mins == 30 ? 3.00 : (mins == 60 ? 5.00 : 9.00);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () => setState(() => _selectedExtraMinutes = mins),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.surface : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.dark : AppColors.divider,
                                    width: isSelected ? 2.0 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                          color: isSelected ? AppColors.dark : AppColors.hint,
                                        ),
                                        const SizedBox(width: 12),
                                        Text('$mins Minutes',
                                            style: inter(16, weight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text('RM ${price.toStringAsFixed(2)}',
                                        style: inter(16, weight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const Spacer(),
                        PrimaryButton(
                          label: _submitting ? 'Processing Extension...' : 'Confirm & Pay Extension',
                          onPressed: _submitting ? null : _confirmExtension,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Cancel', style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }
}