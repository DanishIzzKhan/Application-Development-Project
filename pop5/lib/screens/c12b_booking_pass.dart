import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/active_rental.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// C12b Booking pass: the QR the owner scans at the counter (rentals.qr_token).
class BookingPassScreen extends StatefulWidget {
  final String rentalId;
  const BookingPassScreen({super.key, required this.rentalId});

  @override
  State<BookingPassScreen> createState() => _BookingPassScreenState();
}

class _BookingPassScreenState extends State<BookingPassScreen> {
  Map<String, dynamic>? _row;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await supabase
          .from('rentals')
          .select('*, vehicles(id, type)')
          .eq('id', widget.rentalId)
          .single();
      if (mounted) setState(() => _row = row);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _row;
    return Scaffold(
      appBar: const AppHeader(title: 'Booking pass'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : row == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load your booking pass.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                        ),
                        TextButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  )
                : _content(row),
      ),
    );
  }

  Widget _content(Map<String, dynamic> row) {
    final r = ActiveRental.fromMap(row);
    final qr = row['qr_token'] as String;
    final code = (row['booking_code'] as String).toUpperCase();
    final paid = r.status != 'pending_payment';
    final starts = r.start.isBefore(DateTime.now().add(const Duration(minutes: 2)))
        ? 'Now'
        : formatDateTime(r.start);
    final mins = r.blocks * 20;

    Widget detail(String left, Widget right) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: inter(14, color: AppColors.text2)),
            right,
          ],
        );

    return FormScroll(
      children: [
        Text('Show this at the counter',
            textAlign: TextAlign.center,
            style: inter(18, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('The shop scans it to hand over your vehicle.',
            textAlign: TextAlign.center,
            style: inter(13, color: AppColors.text2)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 1.5),
          ),
          child: Column(
            children: [
              QrImageView(
                data: qr,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 10),
              Text(code,
                  style: inter(22, weight: FontWeight.w700)
                      .copyWith(letterSpacing: 2)),
              const SizedBox(height: 2),
              Text('Booking code (if scanning fails)',
                  style: inter(12, color: AppColors.text2)),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1.5, color: AppColors.divider),
              const SizedBox(height: 14),
              detail('Vehicle',
                  Text(r.vehicleName, style: inter(14, weight: FontWeight.w600))),
              const SizedBox(height: 8),
              detail('Start',
                  Text(starts, style: inter(14, weight: FontWeight.w600))),
              const SizedBox(height: 8),
              detail(
                  'Duration',
                  Text('${mins ~/ 60} hr ${mins % 60} min',
                      style: inter(14, weight: FontWeight.w600))),
              const SizedBox(height: 8),
              detail(
                'Payment',
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: paid ? AppColors.dark : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: paid
                        ? null
                        : Border.all(color: AppColors.dark, width: 1.5),
                  ),
                  child: Text(paid ? 'PAID' : 'PENDING',
                      style: inter(12,
                          weight: FontWeight.w700,
                          color: paid ? Colors.white : AppColors.dark)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, size: 18, color: AppColors.text2),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Turn your screen brightness up so the shop can scan it.',
                  style: inter(12, color: AppColors.text2)),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}