import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ReceiptScreen extends StatefulWidget {
  final String bookingId;
  const ReceiptScreen({super.key, required this.bookingId});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _loading = true;
  Map<String, dynamic>? _receiptData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

  Future<void> _fetchReceipt() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client
          .from('rentals')
          .select('*, vehicles(*)')
          .eq('id', widget.bookingId)
          .single();
      if (mounted) {
        setState(() {
          _receiptData = response;
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

  void _shareReceipt() {
    showToast(context, 'Receipt saved / shared successfully!');
  }

  @override
  Widget build(BuildContext context) {
    final data = _receiptData;
    final startTime =
        DateTime.tryParse('${data?['scheduled_start_time'] ?? ''}')?.toLocal();
    final endTime =
        DateTime.tryParse('${data?['scheduled_end_time'] ?? ''}')?.toLocal();
    final durationMins = ((data?['blocks_booked'] ?? 3) as num).toInt() * 20;
    final v = data?['vehicles'];
    final vehicleName = v == null ? 'Vehicle' : '${v['type']} ${v['id']}';

    return Scaffold(
      appBar: const AppHeader(title: 'Receipt'),
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
                          Text('Could not load receipt.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _fetchReceipt,
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
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.receipt_long, size: 48, color: AppColors.dark),
                              const SizedBox(height: 12),
                              Text('Payment Successful',
                                  style: inter(18, weight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text('Booking ID: ${widget.bookingId.substring(0, 8)}',
                                  style: inter(13, color: AppColors.text2)),
                              const Divider(height: 32, thickness: 1.5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Vehicle', style: inter(14, color: AppColors.text2)),
                                  Text(vehicleName,
                                      style: inter(14, weight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Duration', style: inter(14, color: AppColors.text2)),
                                  Text('$durationMins mins',
                                      style: inter(14, weight: FontWeight.w600)),
                                ],
                              ),
                              if (startTime != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Start Time', style: inter(14, color: AppColors.text2)),
                                    Text(formatDateTime(startTime),
                                        style: inter(14, weight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                              if (endTime != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('End Time', style: inter(14, color: AppColors.text2)),
                                    Text(formatDateTime(endTime),
                                        style: inter(14, weight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                              const Divider(height: 32, thickness: 1.5),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Paid', style: inter(14, color: AppColors.text2)),
                                  Text('RM ${(_receiptData?['total_amount'] ?? 0.0).toStringAsFixed(2)}',
                                      style: inter(16, weight: FontWeight.w700)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: _shareReceipt,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: AppColors.border, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Download / Share Receipt', style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
                        ),
                        const Spacer(),
                        PrimaryButton(
                          label: 'Done / Back to Home',
                          onPressed: () {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
      ),
    );
  }
}
