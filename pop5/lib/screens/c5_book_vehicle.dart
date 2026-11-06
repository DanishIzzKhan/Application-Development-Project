import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

class BookVehicleScreen extends StatefulWidget {
  final Vehicle vehicle;
  const BookVehicleScreen({super.key, required this.vehicle});

  @override
  State<BookVehicleScreen> createState() => _BookVehicleScreenState();
}

class _BookVehicleScreenState extends State<BookVehicleScreen> {
  static const _step = 20; // minutes per tap
  static const _minMinutes = 20;
  static const _maxMinutes = 480;

  DateTime? _start; // null = start now
  int _minutes = 60; // wireframe default: 1 hr 0 min
  bool _agreed = false;
  bool _loading = false;

  int get _blocks => _minutes ~/ _step;
  double get _total => _blocks * widget.vehicle.pricePer20Min;

  String get _durationLabel => '${_minutes ~/ 60} hr ${_minutes % 60} min';

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start ?? now),
    );
    if (time == null) return;
    var picked =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (picked.isBefore(now)) picked = now;
    setState(() => _start = picked);
  }

  Future<void> _continue() async {
    if (!_agreed) {
      showToast(context,
          'Please agree to location sharing and automatic late charges.');
      return;
    }
    setState(() => _loading = true);
    try {
      final id = await Api.createBooking(
        vehicle: widget.vehicle,
        start: _start ?? DateTime.now(),
        durationMinutes: _minutes,
      );
      if (!mounted) return;
      showToast(context,
          'Booking ${id.substring(0, 8)} saved. Payment (C6) is the next screen.');
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (e) {
      if (mounted) showToast(context, 'Could not create booking: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    return Scaffold(
      appBar: AppHeader(title: 'Book ${v.name}'),
      body: SafeArea(
        child: FormScroll(
          children: [
            v.photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(v.photoUrl!,
                        height: 120, width: double.infinity, fit: BoxFit.cover),
                  )
                : DashedBox(
                    height: 120,
                    child: Text('VEHICLE PHOTO',
                        style: inter(12, color: AppColors.text2)),
                  ),
            const SizedBox(height: 12),
            Text(v.name, style: inter(18, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${v.priceLabel} per 20 minutes · inside Kulai Park only',
                style: inter(14, color: AppColors.text2)),
            const SizedBox(height: 12),
            Text('Start time', style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickStart,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _start == null
                            ? 'Now (or choose a later time)'
                            : formatDateTime(_start!),
                        style: inter(15,
                            color: _start == null
                                ? AppColors.hint
                                : AppColors.ink),
                      ),
                    ),
                    if (_start != null)
                      GestureDetector(
                        onTap: () => setState(() => _start = null),
                        child: const Icon(Icons.close, size: 20),
                      )
                    else
                      const Icon(Icons.schedule, size: 20, color: AppColors.hint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('How long?', style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                _stepButton('−', _minutes > _minMinutes
                    ? () => setState(() => _minutes -= _step)
                    : null),
                const SizedBox(width: 16),
                Text(_durationLabel, style: inter(20, weight: FontWeight.w700)),
                const SizedBox(width: 16),
                _stepButton('+', _minutes < _maxMinutes
                    ? () => setState(() => _minutes += _step)
                    : null),
              ],
            ),
            const SizedBox(height: 6),
            Text('Each tap adds or removes 20 minutes',
                style: inter(12, color: AppColors.text2)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Return more than 5 min late and ${Api.lateFee} is charged automatically to your saved card every 20 min.',
                      style: inter(13, color: AppColors.dark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCheckRow(
              value: _agreed,
              onChanged: (x) => setState(() => _agreed = x),
              text:
                  'I agree to location sharing during the rental and to automatic late charges.',
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: AppColors.divider, width: 1.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total ($_blocks × 20 min)',
                      style: inter(14, color: AppColors.text2)),
                  Text('RM ${_total.toStringAsFixed(2)}',
                      style: inter(18, weight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
                label: 'Continue to payment',
                loading: _loading,
                onPressed: _continue),
          ],
        ),
      ),
    );
  }

  Widget _stepButton(String symbol, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.dark, width: 1.5),
          ),
          child: Text(symbol, style: inter(22)),
        ),
      ),
    );
  }
}