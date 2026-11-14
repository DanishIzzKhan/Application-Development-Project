import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/active_rental.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// C10 Extend rental: a bottom sheet over the active-rental screen.
/// Returns true when the rental was extended.
///
/// TESTING: the database function `extend_my_rental` extends straight away and
/// records a pending payment. Later it should wait for the gateway to confirm.
Future<bool?> showExtendSheet(BuildContext context, ActiveRental rental) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ExtendSheet(rental: rental),
  );
}

class _ExtendSheet extends StatefulWidget {
  final ActiveRental rental;
  const _ExtendSheet({required this.rental});

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  static const _maxBlocks = 6; // 2 hours at most per extension

  int _blocks = 1;
  bool _loading = false;
  String? _error;

  ActiveRental get _r => widget.rental;
  DateTime get _newEnd => _r.end.add(Duration(minutes: _blocks * 20));
  double get _cost => _blocks * _r.ratePerBlock;

  Future<void> _confirm() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await supabase.rpc('extend_my_rental',
          params: {'p_rental_id': _r.id, 'p_blocks': _blocks});
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not extend: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget row(String left, String right, {bool bold = false}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(left, style: inter(14, color: AppColors.text2)),
            Text(right,
                style: inter(14,
                    weight: bold ? FontWeight.w700 : FontWeight.w400)),
          ],
        );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 20, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Extend rental', style: inter(20, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${_r.vehicleName} · current end time ${clockLabel(_r.end)}',
                style: inter(14, color: AppColors.text2)),
            const SizedBox(height: 14),
            Text('Add time', style: inter(14, weight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _step('−', _blocks > 1 ? () => setState(() => _blocks--) : null),
                const SizedBox(width: 18),
                Text('+${_blocks * 20} min',
                    style: inter(20, weight: FontWeight.w700)),
                const SizedBox(width: 18),
                _step('+',
                    _blocks < _maxBlocks ? () => setState(() => _blocks++) : null),
              ],
            ),
            const SizedBox(height: 6),
            Text('Each tap adds 20 minutes',
                textAlign: TextAlign.center,
                style: inter(12, color: AppColors.text2)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider, width: 1.5),
              ),
              child: Column(
                children: [
                  row('New end time', clockLabel(_newEnd), bold: true),
                  const SizedBox(height: 6),
                  row('Extra cost', 'RM ${_cost.toStringAsFixed(2)}', bold: true),
                  const SizedBox(height: 6),
                  row('Pay with', "Touch 'n Go eWallet"),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: inter(13, color: Colors.red.shade700)),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
                label: 'Confirm extension',
                loading: _loading,
                onPressed: _confirm),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: inter(14, weight: FontWeight.w600, color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String symbol, VoidCallback? onTap) {
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