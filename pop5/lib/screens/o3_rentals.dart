import 'package:flutter/material.dart';

import '../models/rental.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rental_widgets.dart';
import 'o4_walk_in_booking.dart';
import 'o5_start_rental.dart';

/// O3 Rentals — the "Rentals" tab inside OwnerShell (bottom bar comes from the shell).
class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  // Sample data for now (AppConfig.uiPreviewMode). Later: Api + Realtime.
  late List<OwnerRental> _rentals = sampleOwnerRentals();

  List<OwnerRental> _withStatus(String s) =>
      _rentals.where((r) => r.status == s).toList();

  /// Opens O5. If the owner tapped "Start rental", O5 returns true and the
  /// row moves from "Waiting"/"Ready" to "Active".
  Future<void> _openStart(OwnerRental rental) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StartRentalScreen(rental: rental)),
    );
    if (started == true && mounted) {
      setState(() {
        _rentals = [
          for (final r in _rentals)
            r.id == rental.id ? r.startedAt(DateTime.now()) : r,
        ];
      });
    }
  }

  /// Opens O4. When the owner creates the booking, O4 returns the new
  /// walk-in rental: add it to "Ready for handover", then open O5 for it.
  Future<void> _openWalkIn() async {
    final rental = await Navigator.of(context).push<OwnerRental>(
      MaterialPageRoute(builder: (_) => const WalkInBookingScreen()),
    );
    if (rental == null || !mounted) return;
    setState(() => _rentals = [..._rentals, rental]);
    await _openStart(rental);
  }

  void _comingSoon(String title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _ComingSoonScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final waiting = _withStatus('pending_payment');
    final ready = _withStatus('ready');
    final active = _withStatus('active');

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Text('Rentals', style: inter(20, weight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SmallButton(
              label: '+ Walk-in',
              primary: false,
              onPressed: _openWalkIn, // O4
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.5),
          child: SizedBox(
            height: 1.5,
            width: double.infinity,
            child: ColoredBox(color: AppColors.divider),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _comingSoon('Scan booking'), // O3b
              icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
              label: Text('Scan booking QR',
                  style: inter(15,
                      weight: FontWeight.w600, color: Colors.white)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.dark,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Waiting for payment -> O5 ----
          const SectionTitle('Waiting for payment'),
          for (final r in waiting)
            _RentalRow(
              title: r.title,
              subtitle: 'Pay at counter · ${r.totalLabel}',
              button: SmallButton(
                  label: 'Open', onPressed: () => _openStart(r)),
              onTap: () => _openStart(r),
            ),
          if (waiting.isEmpty) const _EmptyRow(),
          const SizedBox(height: 20),

          // ---- Ready for handover -> O5 ----
          const SectionTitle('Ready for handover'),
          for (final r in ready)
            _RentalRow(
              title: r.title,
              subtitle:
                  '${r.paidOnline ? 'Paid online' : 'Paid at counter'} · ${r.durationLabel}',
              button: SmallButton(
                  label: 'Start', onPressed: () => _openStart(r)),
              onTap: () => _openStart(r),
            ),
          if (ready.isEmpty) const _EmptyRow(),
          const SizedBox(height: 20),

          // ---- Active -> O6 (not built yet) ----
          const SectionTitle('Active'),
          for (final r in active)
            _RentalRow(
              title: r.title,
              subtitle: _activeLine(r, now),
              badge: r.isWalkIn && r.minutesLate(now) > 0
                  ? const RentalBadge('OVERDUE')
                  : null,
              button: SmallButton(
                label: 'End',
                primary: false,
                onPressed: () => _comingSoon('End rental'), // O6
              ),
              onTap: () => _comingSoon('End rental'), // O6
            ),
          if (active.isEmpty) const _EmptyRow(),
        ],
      ),
    );
  }

  /// Second line of an active row, e.g. "+0:10 late · 1 block auto-charged".
  String _activeLine(OwnerRental r, DateTime now) {
    final late = r.minutesLate(now);
    if (late == 0) return 'Until ${formatClock(r.scheduledEnd)}';
    if (r.isWalkIn) {
      return '${formatLate(late)} overdue · extra ${formatRM(r.lateCharge(now))} · not tracked';
    }
    final blocks = r.lateBlocks(now);
    if (blocks == 0) return '${formatLate(late)} late · in grace period';
    return '${formatLate(late)} late · $blocks block${blocks == 1 ? '' : 's'} auto-charged';
  }
}

/// One list row: two lines of text, optional badge, button on the right,
/// divider underneath. Tapping the whole row does the same as the button.
class _RentalRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget button;
  final Widget? badge;
  final VoidCallback onTap;

  const _RentalRow({
    required this.title,
    required this.subtitle,
    required this.button,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 1.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: inter(15, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: inter(13, color: AppColors.text2)),
                ],
              ),
            ),
            if (badge != null) ...[badge!, const SizedBox(width: 8)],
            button,
          ],
        ),
      ),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text('None right now', style: inter(13, color: AppColors.hint)),
    );
  }
}

/// Temporary page for screens that are not built yet (O3b, O4, O6).
class _ComingSoonScreen extends StatelessWidget {
  final String title;
  const _ComingSoonScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(title: title),
      body: Center(
        child: Text('Coming soon', style: inter(15, color: AppColors.hint)),
      ),
    );
  }
}
