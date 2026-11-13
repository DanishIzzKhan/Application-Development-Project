import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c10_extend_rental.dart';
import 'c11_report_problem.dart';

class ActiveRentalScreen extends StatefulWidget {
  final String bookingId;
  const ActiveRentalScreen({super.key, required this.bookingId});

  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  bool _loading = true;
  Map<String, dynamic>? _rentalData;
  String? _error;
  Timer? _ticker;
  Duration _remainingTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    _fetchActiveRental();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTime();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchActiveRental() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('rentals')
          .select('*, vehicles(id, type, rate_per_block)')
          .eq('id', widget.bookingId)
          .single();
      if (mounted) {
        setState(() {
          _rentalData = response;
          _loading = false;
        });
        _calculateTime();
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

  void _calculateTime() {
    if (_rentalData == null || _rentalData!['end_time'] == null) return;
    final endTime = DateTime.tryParse(_rentalData!['end_time']);
    if (endTime == null) return;

    final now = DateTime.now();
    final difference = endTime.difference(now);

    if (mounted) {
      setState(() {
        if (!difference.isNegative) {
          _remainingTime = difference;
        } else {
          _remainingTime = Duration.zero;
        }
      });
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _returnVehicle() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('rentals')
          .update({'status': 'completed'}).eq('id', widget.bookingId);

      if (!mounted) return;
      showToast(context, 'Vehicle returned successfully!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to return vehicle: $e');
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openExtend() async {
    final extended = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => ExtendRentalScreen(bookingId: widget.bookingId)),
    );
    if (extended == true && mounted) _fetchActiveRental();
  }

  void _openReport() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReportProblemScreen(bookingId: widget.bookingId)));
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = _rentalData?['vehicles']?['name'] ?? 'Vehicle';
    final vehicleType = _rentalData?['vehicles']?['type'] ?? 'bicycle';

    return Scaffold(
      appBar: const AppHeader(title: 'Active Rental (C9)'),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.dark))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Could not load active rental.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _fetchActiveRental,
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
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.divider, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.pedal_bike,
                                  size: 56, color: AppColors.dark),
                              const SizedBox(height: 16),
                              Text('Rental in Progress',
                                  style: inter(18, weight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Text('$vehicleName ($vehicleType)',
                                  style: inter(14, color: AppColors.text2)),
                              const SizedBox(height: 24),
                              Text(_formatDuration(_remainingTime),
                                  style: inter(36, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Time remaining',
                                  style: inter(12, color: AppColors.text2)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: 'Return Vehicle',
                          onPressed: _returnVehicle,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _openExtend,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(
                                color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Extend Rental (C10)',
                              style: inter(14,
                                  weight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _openReport,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(
                                color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Report a Problem (C11)',
                              style: inter(14,
                                  weight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }
}
