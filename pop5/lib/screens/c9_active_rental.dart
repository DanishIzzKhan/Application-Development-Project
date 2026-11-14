import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/active_rental.dart';
import '../services/api.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'c3_vehicles.dart';
import 'c9d_pay_late_charge.dart';
import 'c10_extend_rental.dart';
import 'c11_report_problem.dart';
import 'c12_my_rentals.dart';
import 'c13_notifications.dart';
import 'c14_settings.dart';

/// C9 Active rental. One screen with three looks that switch by themselves
/// as the clock runs:
///   more than 10 min left -> C9, 10 min or less -> C9b, past the end -> C9c.
class ActiveRentalScreen extends StatefulWidget {
  final String bookingId; // rentals.id
  const ActiveRentalScreen({super.key, required this.bookingId});

  @override
  State<ActiveRentalScreen> createState() => _ActiveRentalScreenState();
}

class _ActiveRentalScreenState extends State<ActiveRentalScreen> {
  /// Becomes true when GPS tracking says the rider is close to the park edge.
  /// GPS is not connected yet, so this stays false.
  static const _nearBoundary = false;

  ActiveRental? _r;
  String? _error;
  bool _loading = true;
  int _unread = 0;
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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
          .eq('id', widget.bookingId)
          .single();
      final unread = await Api.fetchUnreadCount();
      if (!mounted) return;
      setState(() {
        _r = ActiveRental.fromMap(row);
        _unread = unread;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _extend() async {
    final r = _r;
    if (r == null) return;
    final ok = await showExtendSheet(context, r);
    if (ok == true && mounted) {
      showToast(context, 'Rental extended.');
      _load();
    }
  }

  void _report() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ReportProblemScreen(bookingId: widget.bookingId)));
  }

  void _payLate() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PayLateChargeScreen(rentalId: widget.bookingId)));
  }

  void _openTab(int index) {
    final Widget dest = switch (index) {
      0 => const VehiclesScreen(),
      1 => const MyRentalsScreen(),
      2 => const NotificationsScreen(),
      _ => const SettingsScreen(),
    };
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionDuration: Duration.zero,
      ),
      (_) => false,
    );
  }

  String _hms(Duration d) {
    final s = d.inSeconds.abs();
    final h = s ~/ 3600;
    final m = ((s % 3600) ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$h:$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      appBar: AppHeader(title: r?.vehicleName ?? 'Rental', showBack: false),
      bottomNavigationBar: SafeArea(
        child: _NavBar(unread: _unread, onSelect: _openTab),
      ),
      body: SafeArea(
        child: _loading && r == null
            ? const Center(child: CircularProgressIndicator())
            : r == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('Could not load this rental.\n$_error',
                              textAlign: TextAlign.center,
                              style: inter(14, color: AppColors.text2)),
                        ),
                        TextButton(
                            onPressed: _load, child: const Text('Try again')),
                      ],
                    ),
                  )
                : _content(r),
      ),
    );
  }

  Widget _content(ActiveRental r) {
    final left = r.timeLeft(_now);
    final overdue = left.isNegative;
    final tenMin = !overdue && left <= const Duration(minutes: 10);
    final lateBy = r.lateBy(_now);
    final fraction = overdue
        ? 0.0
        : (left.inSeconds / r.bookedDuration.inSeconds).clamp(0.0, 1.0);
    final blocks = r.lateBlocks(_now);
    final minsLeft = (left.inSeconds / 60).ceil();

    return FormScroll(
      children: [
        // ---- banner ----
        if (overdue)
          _banner(Icons.warning_amber_rounded, 'Overdue.',
              ' Please return the vehicle to the shop now.')
        else if (tenMin)
          _banner(Icons.timer_outlined,
              '$minsLeft minute${minsLeft == 1 ? '' : 's'} left.',
              ' Head back to the shop or extend now.')
        else if (_nearBoundary)
          _banner(Icons.location_on_outlined, 'Near the park boundary.',
              ' Please turn back.'),
        if (overdue || tenMin || _nearBoundary) const SizedBox(height: 14),

        // ---- countdown ring ----
        Center(
          child: SizedBox(
            width: 190,
            height: 190,
            child: CustomPaint(
              painter: _RingPainter(fraction: fraction, dashed: overdue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(overdue ? Icons.warning_amber_rounded : Icons.timer_outlined,
                      size: 26),
                  const SizedBox(height: 6),
                  Text(overdue ? '+${_hms(lateBy)}' : _hms(left),
                      style: inter(overdue ? 26 : 32, weight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(overdue ? 'overdue' : 'remaining',
                      style: inter(13, color: AppColors.text2)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (!overdue)
          Text('Return by ${clockLabel(r.end)}',
              textAlign: TextAlign.center,
              style: inter(13, weight: FontWeight.w600)),

        // ---- extra charge card (overdue only) ----
        if (overdue) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.dark, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-charged so far',
                        style: inter(14, weight: FontWeight.w600)),
                    Text(
                        blocks == 0
                            ? 'None yet'
                            : '$blocks × ${rmOrX(r.lateRate)}',
                        style: inter(14, weight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  blocks == 0
                      ? 'You are inside the ${r.graceMinutes} min free period. Charges start after ${clockLabel(r.nextChargeAt(_now))}.'
                      : 'Charged automatically to Visa •••• 4417. Return by ${clockLabel(r.nextChargeAt(_now))} to avoid the next ${rmOrX(r.lateRate)} charge.',
                  style: inter(12, color: AppColors.text2),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _payLate,
                  child: Text('Charge failed? Pay here ›',
                      style: inter(13, weight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),

        // ---- map placeholder ----
        _mapBox(overdue ? 130 : 150),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 16),
            const SizedBox(width: 6),
            Text('Location sharing on',
                style: inter(13, color: AppColors.dark)),
          ],
        ),

        const Spacer(),
        const SizedBox(height: 14),

        // ---- actions (none when overdue: just return the vehicle) ----
        if (!overdue)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: tenMin
                      ? FilledButton(
                          onPressed: _extend,
                          style: _filledStyle,
                          child: Text('Extend 20 min',
                              style: inter(15,
                                  weight: FontWeight.w600,
                                  color: Colors.white)),
                        )
                      : OutlinedButton(
                          onPressed: _extend,
                          style: _outlinedStyle,
                          child: Text('Extend 20 min',
                              style: inter(15, weight: FontWeight.w600)),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _report,
                    style: _outlinedStyle,
                    child: Text('Report a problem',
                        style: inter(15, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _report,
              style: _outlinedStyle,
              child: Text('Report a problem',
                  style: inter(15, weight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  ButtonStyle get _outlinedStyle => OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.dark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  ButtonStyle get _filledStyle => FilledButton.styleFrom(
        backgroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _banner(IconData icon, String bold, String rest) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.dark, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: inter(14),
                children: [
                  TextSpan(text: bold, style: inter(14, weight: FontWeight.w700)),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapBox(double height) {
    return SizedBox(
      height: height,
      child: DashedBox(
        height: height,
        radius: 10,
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                left: 14,
                top: 8,
                child: Text('MAP · you are inside Kulai Park',
                    style: inter(12, color: AppColors.text2)),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 14),
                  child: CustomPaint(painter: _DashedOutline(radius: 45)),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                          color: AppColors.dark, shape: BoxShape.circle),
                    ),
                    const SizedBox(height: 2),
                    Text('You', style: inter(12, weight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Track + arc (remaining time), or a dashed ring when overdue.
class _RingPainter extends CustomPainter {
  final double fraction;
  final bool dashed;
  _RingPainter({required this.fraction, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - stroke / 2,
    );
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE5E5E5);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.dark;

    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (dashed) {
      const dashes = 28;
      const step = 2 * math.pi / dashes;
      for (var i = 0; i < dashes; i++) {
        canvas.drawArc(rect, -math.pi / 2 + i * step, step * 0.55, false, arc);
      }
    } else if (fraction > 0) {
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, arc);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.dashed != dashed;
}

/// Dashed rounded outline (the park boundary on the map placeholder).
class _DashedOutline extends CustomPainter {
  final double radius;
  _DashedOutline({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.dark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
              Offset.zero & size, Radius.circular(radius))
          .deflate(1));
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutline old) => old.radius != radius;
}

class _NavBar extends StatelessWidget {
  final int unread;
  final ValueChanged<int> onSelect;
  const _NavBar({required this.unread, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1.5)),
      ),
      child: Row(
        children: [
          _item(Icons.pedal_bike, 'Rent', 0, false),
          _item(Icons.receipt_long_outlined, 'My rentals', 1, true),
          _item(Icons.notifications_none, 'Notifications', 2, false,
              badge: unread),
          _item(Icons.settings_outlined, 'Settings', 3, false),
        ],
      ),
    );
  }

  Widget _item(IconData icon, String label, int index, bool current,
      {int badge = 0}) {
    final color = current ? AppColors.ink : AppColors.hint;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(index),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 3),
                Text(label,
                    style: inter(11,
                        weight: current ? FontWeight.w700 : FontWeight.w400,
                        color: color)),
              ],
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                left: 53,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: AppColors.ink, shape: BoxShape.circle),
                  child: Text('$badge',
                      style: inter(10,
                          weight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
