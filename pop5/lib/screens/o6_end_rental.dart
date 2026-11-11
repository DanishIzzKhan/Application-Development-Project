import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';
import 'o3c_customer_details.dart';
import 'o6b_collect_payment.dart';
import 'o6c_rental_completed.dart';

/// O6 End rental — opened from "End" (or tapping an Active row) on O3.
/// Pops with `true` when the owner ends the rental, so O3 removes it.
class EndRentalScreen extends StatefulWidget {
  final OwnerRental rental;
  const EndRentalScreen({super.key, required this.rental});

  @override
  State<EndRentalScreen> createState() => _EndRentalScreenState();
}

class _EndRentalScreenState extends State<EndRentalScreen> {
  /// When O6 was opened = when the owner is ending the rental.
  final DateTime _openedAt = DateTime.now();

  /// Actual return time. Starts as "now"; the owner can set it earlier
  /// if the vehicle came back before they ended the rental.
  /// Uses the time saved by "Returned" on O3 if the owner tapped it.
  late DateTime _returnTime = _r.returnedAt ?? _openedAt;

  bool _waived = false; // owner chose to forgive the late charge
  VehicleCondition _condition = VehicleCondition.good;

  // Issue details, only asked for Minor issue / Damaged
  // (vehicle_condition_checks.notes and photo_url).
  final _issueNote = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _issuePhoto;

  bool get _hasIssue => _condition != VehicleCondition.good;

  /// Minutes the vehicle came back before the booked end (no refund).
  int get _earlyMin {
    final m = _r.scheduledEnd.difference(_returnTime).inMinutes;
    return m > 0 ? m : 0;
  }

  /// What is still missing before the rental can be ended.
  List<String> get _missing => [
        if (_hasIssue && _issueNote.text.trim().isEmpty) 'Describe the issue',
      ];

  bool get _canEnd => _missing.isEmpty;

  @override
  void initState() {
    super.initState();
    // Redraw while typing, so the End button turns dark once filled.
    _issueNote.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _issueNote.dispose();
    super.dispose();
  }

  OwnerRental get _r => widget.rental;

  // ---------- Late charge maths (rule lives in rental.dart) ----------

  int get _lateMin => _r.minutesLate(_returnTime);

  /// Late blocks for the actual return time, before any waiver.
  int get _lateBlocks => OwnerRental.lateBlocksFor(_lateMin);

  /// Late blocks the customer really pays.
  int get _owedBlocks => _waived ? 0 : _lateBlocks;

  /// Late blocks already auto-charged to the saved card (0 for walk-ins).
  int get _chargedBlocks => _r.autoChargedBlocks(_openedAt);

  /// Charged but not owed (return time edited, or waived) -> refunded.
  int get _refundBlocks => max(0, _chargedBlocks - _owedBlocks);

  /// Owed but not charged yet. Walk-ins pay this at the counter (O6b).
  int get _extraBlocks => max(0, _owedBlocks - _chargedBlocks);

  double _money(int blocks) => blocks * _r.lateRatePerBlock;
  double get _total => _r.rentalTotal + _money(_owedBlocks);

  /// Late walk-in: no saved card, so payment must be collected first.
  bool get _mustCollect => _r.isWalkIn && _extraBlocks > 0;

  // ---------- Actions ----------

  Future<void> _pickReturnTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_returnTime),
      helpText: 'Actual return time',
    );
    if (picked == null || !mounted) return;
    final t = DateTime(_openedAt.year, _openedAt.month, _openedAt.day,
        picked.hour, picked.minute);

    if (t.isAfter(DateTime.now())) {
      showTopNotice(context,
          title: "Return time can't be later than now", type: NoticeType.error);
      return;
    }
    if (t.isBefore(_r.scheduledStart)) {
      showTopNotice(context,
          title: "Return time can't be before the rental started",
          lines: ['Started at ${formatClock(_r.scheduledStart)}'],
          type: NoticeType.error);
      return;
    }
    setState(() => _returnTime = t);
    if (_refundBlocks > 0 && !_waived) {
      showTopNotice(context,
          title: '${formatRM(_money(_refundBlocks))} will be refunded',
          lines: ['Late charge was auto-charged by mistake.'],
          type: NoticeType.info);
    }
  }

  Future<void> _toggleWaive() async {
    if (_waived) {
      setState(() => _waived = false);
      showTopNotice(context, title: 'Late charge added back');
      return;
    }
    final amount = formatRM(_money(_lateBlocks));
    final refund = formatRM(_money(_chargedBlocks));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Waive late charge?',
            style: inter(18, weight: FontWeight.w700)),
        content: Text(
          'The customer will not pay the $amount late charge.'
          '${_chargedBlocks > 0 ? ' $refund already charged will be refunded.' : ''}',
          style: inter(14, color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: inter(14, color: AppColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Waive', style: inter(14, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _waived = true);
    showTopNotice(context,
        title: 'Late charge waived',
        lines: [if (_refundBlocks > 0) '$refund will be refunded'],
        type: NoticeType.success);
  }

  void _openCustomerDetails() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CustomerDetailsScreen(rental: _r),
    ));
  }

  /// Opens O6b. Used for a late walk-in ("Collect RM X · end rental") and
  /// for "Auto-charge failed? Collect payment manually ›" (app customers).
  /// When O6b returns a payment method, the rental is ended.
  Future<void> _collectPayment() async {
    if (!_canEnd) {
      _showMissing(); // e.g. issue not described yet
      return;
    }
    // Walk-in: the late blocks not paid yet. App customer whose auto-charge
    // failed: all late blocks owed.
    final blocks = _r.isWalkIn ? _extraBlocks : _owedBlocks;
    if (blocks == 0) {
      showTopNotice(context, title: 'Nothing to collect');
      return;
    }
    final method = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CollectPaymentScreen(
          rental: _r,
          blocks: blocks,
          amount: _money(blocks),
        ),
      ),
    );
    if (method == null || !mounted) return; // Cancel -> stay on O6
    _finishEnd(collected: _money(blocks), method: method);
  }

  Future<void> _takeIssuePhoto() async {
    try {
      final file = await _picker.pickImage(
          source: ImageSource.camera, maxWidth: 1600, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _issuePhoto = bytes);
    } catch (_) {
      if (mounted) {
        showTopNotice(context,
            title: 'Could not open the camera', type: NoticeType.error);
      }
    }
  }

  /// Grey End button tapped: say what is missing.
  void _showMissing() {
    showTopNotice(context,
        title: "Can't end rental yet", lines: _missing, type: NoticeType.error);
  }

  void _endRental() {
    if (_mustCollect) {
      _collectPayment();
      return;
    }
    _finishEnd();
  }

  /// Ends the rental. [collected] / [method] are set when O6b took a payment.
  void _finishEnd({double? collected, String? method}) {
    // Later: Api.endRental(rental.id, returnTime: _returnTime,
    //   condition: _condition, waived: _waived) sets actual_end_time and
    //   status 'completed'; an Edge Function refunds any mistaken charge.
    //   It also saves a vehicle_condition_checks row (stage 'return',
    //   condition, notes = _issueNote, photo_url = uploaded _issuePhoto).

    // O6c replaces O6. `result: true` tells O3 the rental ended, so O3
    // removes it from Active.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RentalCompletedScreen(
          rental: _r,
          returnTime: _returnTime,
          lateMinutes: _lateMin,
          totalPaid: _total,
          paymentLine: _paymentLine(collected, method),
          refunded: _money(_refundBlocks),
          condition: _condition,
          charges: _chargeRows(),
        ),
      ),
      result: true,
    );
  }

  /// "Payment" row on O6c, e.g. "Late charge auto-charged ✓".
  String _paymentLine(double? collected, String? method) {
    if (collected != null) {
      return 'Late charge paid · ${_methodLabel(method)} ✓';
    }
    if (_waived && _lateBlocks > 0) return 'Late charge waived';
    if (_owedBlocks > 0 && !_r.isWalkIn) return 'Late charge auto-charged ✓';
    if (_r.isWalkIn) return 'Paid at the counter ✓';
    return _r.paidOnline ? 'Paid online ✓' : 'Paid at the counter ✓';
  }

  String _methodLabel(String? m) => switch (m) {
        'Cash' => 'Cash',
        'TnG' => 'Touch ’n Go / bank QR',
        'Card' => 'paid in the app',
        _ => 'paid',
      };

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'End rental'),
      body: FormScroll(
        children: [
          _rentalCard(),
          const SizedBox(height: 12),
          ChargesTable(rows: _chargeRows(), total: formatRM(_total)),

          // ---- Waive late charge (only when late) ----
          if (_lateBlocks > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                      _waived ? 'Late charge waived' : 'Waive late charge?',
                      style: inter(14, weight: FontWeight.w600)),
                ),
                SmallButton(
                  label: _waived ? 'Undo' : (_r.isWalkIn ? 'Waive' : 'Refund'),
                  icon: _waived ? Icons.undo : Icons.currency_exchange,
                  primary: false,
                  onPressed: _toggleWaive,
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // ---- Condition ----
          const SectionTitle('Condition at return'),
          const SizedBox(height: 10),
          ConditionChips(
            value: _condition,
            onChanged: (c) => setState(() => _condition = c),
          ),

          // ---- Issue details (Minor issue / Damaged only) ----
          if (_hasIssue) ...[
            const SizedBox(height: 12),
            AppField(
              label: 'What is wrong?',
              hint: 'e.g. brakes feel loose',
              controller: _issueNote,
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _takeIssuePhoto,
              child: DashedBox(
                height: 80,
                child: _issuePhoto != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(_issuePhoto!,
                                width: 88, height: 60, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          Text('Photo added ✓ (tap to retake)',
                              style: inter(13, weight: FontWeight.w600)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 22),
                          const SizedBox(height: 4),
                          Text('Add photo of the issue (optional)',
                              style: inter(13, weight: FontWeight.w600)),
                        ],
                      ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          InkWell(
            onTap: _openCustomerDetails,
            child: Text('View customer details ›',
                style: inter(13, weight: FontWeight.w600)),
          ),

          const Spacer(),
          const SizedBox(height: 16),
          if (!_r.isWalkIn) ...[
            Center(
              child: InkWell(
                onTap: _collectPayment,
                child: Text('Auto-charge failed? Collect payment manually ›',
                    style: inter(13,
                        weight: FontWeight.w600, color: AppColors.text2)),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Grey until the issue is described (Minor issue / Damaged).
          // A tap on the grey button shows what is missing.
          GestureDetector(
            onTap: _canEnd ? null : _showMissing,
            child: PrimaryButton(
              label: _mustCollect
                  ? 'Collect ${formatRM(_money(_extraBlocks))} · end rental'
                  : 'End rental',
              onPressed: _canEnd ? _endRental : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rentalCard() {
    return OutlinedCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_r.title, style: inter(16, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          _infoRow(
              'Booked until',
              Text(formatClock(_r.scheduledEnd),
                  style: inter(14, weight: FontWeight.w600))),
          _infoRow(
            'Actual return time',
            InkWell(
              onTap: _pickReturnTime,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.dark, width: 1.5),
                ),
                child: Text('${formatClock(_returnTime)} ✎',
                    style: inter(14, weight: FontWeight.w600)),
              ),
            ),
          ),
          Text(
            _r.isReturned
                ? 'Saved when you tapped Returned. Edit only if that was wrong. '
                    'Charges made by mistake are refunded automatically.'
                : 'Edit if the vehicle came back before you ended the rental. '
                    'Charges made by mistake are refunded automatically.',
            style: inter(12, color: AppColors.hint),
          ),
          if (_lateMin > 0)
            _infoRow(
              'Late by',
              Text('$_lateMin min (${OwnerRental.graceMinutes} min grace)',
                  style: inter(14, weight: FontWeight.w700)),
            ),
          // Early return: customer's choice, so no refund for unused time.
          if (_earlyMin > 0)
            _infoRow(
              'Returned early',
              Text('$_earlyMin min · no refund',
                  style: inter(14, weight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
                child: Text(label, style: inter(14, color: AppColors.text2))),
            value,
          ],
        ),
      );

  List<ChargeRow> _chargeRows() {
    final rows = [
      ChargeRow(
          'Rental (${_r.blocksBooked} × 20 min)', formatRM(_r.rentalTotal),
          note: 'paid'),
    ];
    if (_lateBlocks > 0) {
      if (_waived) {
        rows.add(ChargeRow('Late charge ($_lateBlocks × 20 min)', formatRM(0),
            note: 'waived'));
      } else {
        final note = _r.isWalkIn
            ? 'to collect'
            : (_chargedBlocks >= _owedBlocks
                ? 'auto-charged'
                : 'charged when ended');
        rows.add(ChargeRow('Late charge ($_owedBlocks × 20 min)',
            formatRM(_money(_owedBlocks)),
            note: note));
      }
    }
    if (_refundBlocks > 0) {
      rows.add(ChargeRow(
        _waived ? 'Refund (late charge waived)' : 'Refund (charged by mistake)',
        '− ${formatRM(_money(_refundBlocks))}',
        note: 'refunded automatically',
      ));
    }
    return rows;
  }
}
