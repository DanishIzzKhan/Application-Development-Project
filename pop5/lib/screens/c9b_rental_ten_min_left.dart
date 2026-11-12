import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c10_extend_rental.dart';

class RentalTenMinLeftScreen extends StatefulWidget {
  final String bookingId;
  const RentalTenMinLeftScreen({super.key, required this.bookingId});

  @override
  State<RentalTenMinLeftScreen> createState() => _RentalTenMinLeftScreenState();
}

class _RentalTenMinLeftScreenState extends State<RentalTenMinLeftScreen> {
  bool _loading = true;
  Map<String, dynamic>? _rentalData;
  String? _error;
  Timer? _ticker;
  Duration _remainingTime = const Duration(minutes: 9, seconds: 45);

  @override
  void initState() {
    super.initState();
    _fetchRental();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingTime.inSeconds > 0) {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });
      }
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
    return '$minutes:$seconds';
  }

  Future<void> _returnVehicle() async {
    setState(() => _loading = true);
    try {
      await Supabase.instance.client
          .from('bookings')
          .update({'status': 'completed'})
          .eq('id', widget.bookingId);
      
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
    if (extended == true && mounted) _fetchRental();
  }

  @override
  Widget build(BuildContext context) {
    final vehicleName = _rentalData?['vehicles']?['name'] ?? 'Vehicle';
    final vehicleType = _rentalData?['vehicles']?['type'] ?? 'bicycle';

    return Scaffold(
      appBar: const AppHeader(title: 'Rental - 10 Min Left (C9b)'),
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
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange.shade300, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.timer_outlined, size: 56, color: Colors.orange.shade800),
                              const SizedBox(height: 16),
                              Text('10 Minutes Left!',
                                  style: inter(18, weight: FontWeight.w700, color: Colors.orange.shade800)),
                              const SizedBox(height: 8),
                              Text('$vehicleName ($vehicleType)', style: inter(14, color: AppColors.text2)),
                              const SizedBox(height: 24),
                              Text(_formatDuration(_remainingTime),
                                  style: inter(36, weight: FontWeight.w700, color: Colors.orange.shade800)),
                              const SizedBox(height: 4),
                              Text('Please return the vehicle soon to avoid late fees',
                                  style: inter(12, color: Colors.orange.shade800), textAlign: TextAlign.center),
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
                          onPressed: _openExtend,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Extend Rental (C10)', style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }
}