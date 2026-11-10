import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';

class RentalOverdueScreen extends StatefulWidget {
  final String bookingId;
  const RentalOverdueScreen({super.key, required this.bookingId});

  @override
  State<RentalOverdueScreen> createState() => _RentalOverdueScreenState();
}

class _RentalOverdueScreenState extends State<RentalOverdueScreen> {
  bool _loading = true;
  Map<String, dynamic>? _rentalData;
  String? _error;
  Timer? _ticker;
  Duration _overdueTime = const Duration(minutes: 5, seconds: 12);

  @override
  void initState() {
    super.initState();
    _fetchRental();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _overdueTime = _overdueTime + const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _fetchRental() async {
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

  String _formatDuration(Duration d) {
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '+ $minutes:$seconds';
  }

  Future<void> _returnVehicle() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'completed'})
          .eq('id', widget.bookingId);
      
      if (!mounted) return;
      showToast(context, 'Vehicle returned. Late charges applied.');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) {
        showToast(context, 'Failed to return vehicle: $e');
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = _rentalData?['vehicles']?['name'] ?? 'Vehicle';
    final vehicleType = _rentalData?['vehicles']?['type'] ?? 'bicycle';

    return Scaffold(
      appBar: const AppHeader(title: 'Rental - Overdue (C9c)'),
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
                          Text('Could not load rental info.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _fetchRental,
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
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.shade300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 56, color: Colors.red.shade700),
                              const SizedBox(height: 16),
                              Text('Rental Overdue!',
                                  style: inter(18, weight: FontWeight.w700, color: Colors.red.shade700)),
                              const SizedBox(height: 8),
                              Text('$vehicleName ($vehicleType)', style: inter(14, color: AppColors.text2)),
                              const SizedBox(height: 24),
                              Text(_formatDuration(_overdueTime),
                                  style: inter(36, weight: FontWeight.w700, color: Colors.red.shade700)),
                              const SizedBox(height: 4),
                              Text('Late charges are being charged automatically',
                                  style: inter(12, color: Colors.red.shade700), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: 'Return Vehicle Now',
                          onPressed: _returnVehicle,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => showToast(context, 'Navigate to Report a Problem (C11)'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Report a Problem (C11)', style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }
}