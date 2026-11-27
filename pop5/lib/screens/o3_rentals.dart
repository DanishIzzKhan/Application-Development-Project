import 'package:flutter/material.dart';

import '../config.dart';
import '../models/rental.dart';
import '../services/owner_api.dart';
import '../theme.dart';
import '../widgets/rental_widgets.dart';
import 'o3b_scan_booking.dart';
import 'o4_walk_in_booking.dart';
import 'o5_start_rental.dart';
import 'o6_end_rental.dart';

/// O3 Rentals — the "Rentals" tab inside OwnerShell (bottom bar comes from the shell).
///
/// Shows real bookings from Supabase (OwnerApi.fetchOpenRentals). Pull down
/// to refresh. Walk-ins made on O4 are saved there and show up here too.
class RentalsScreen extends StatefulWidget {
  const RentalsScreen({super.key});

  @override
  State<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends State<RentalsScreen> {
  /// Bookings loaded from Supabase.
  List<OwnerRental> _dbRentals = [];

  /// Only in the app: walk-ins from O4 (not saved yet), or the sample
  /// rentals when AppConfig.uiPreviewMode is on.
  List<OwnerRental> _appOnly =
      AppConfig.uiPreviewMode ? sampleOwnerRentals() : [];

  bool _loading = !AppConfig.uiPreviewMode;
  bool _loadFailed = false;

  List<OwnerRental> get _rentals => [..._dbRentals, ..._appOnly];

  List<OwnerRental> _withStatus(List<String> statuses) =>
      _rentals.where((r) => statuses.contains(r.status)).toList();

  @override
  void initState() {
    super.initState();
    if (!AppConfig.uiPreviewMode) _load();
  }

  /// (Re)loads the bookings from Supabase.
  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final rows = await OwnerApi.fetchOpenRentals();
      if (!mounted) return;
      setState(() {
        _dbRentals = rows;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Rentals: could not load bookings. $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  /// Replaces one app-only rental (walk-in / sample) with [update].
  void _updateAppOnly(String id, OwnerRental Function(OwnerRental) update) {
    setState(() {
      _appOnly = [for (final r in _appOnly) r.id == id ? update(r) : r];
    });
  }

  /// Opens O5. If the owner tapped "Start rental", O5 returns true and the
  /// row moves from "Waiting"/"Ready" to "Active".
  Future<void> _openStart(OwnerRental rental) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => StartRentalScreen(rental: rental)),
    );
    if (started != true || !mounted) return;
    if (rental.fromDatabase) {
      await _load(); // the database now says 'active'
    } else {
      _updateAppOnly(rental.id, (r) => r.startedAt(DateTime.now()));
    }
  }

  /// Opens O4. When the owner creates the booking, O4 returns the new
  /// walk-in rental: add it to "Ready for handover", then open O5 for it.
  Future<void> _openWalkIn() async {
    final rental = await Navigator.of(context).push<OwnerRental>(
      MaterialPageRoute(builder: (_) => const WalkInBookingScreen()),
    );
    if (rental == null || !mounted) return;
    if (rental.fromDatabase) {
      await _load(); // the new walk-in is now under Ready for handover
    } else {
      setState(() => _appOnly = [..._appOnly, rental]);
    }
    if (!mounted) return;
    await _openStart(rental);
  }

  /// One tap the moment the vehicle physically arrives: saves the time,
  /// stops further late charges, and lets the owner do O6 later.
  Future<void> _markReturned(OwnerRental rental) async {
    final at = DateTime.now();
    if (rental.fromDatabase) {
      try {
        await OwnerApi.markReturned(rental.id); // owner_mark_returned
      } catch (e) {
        debugPrint('Returned failed: $e');
        if (mounted) {
          showTopNotice(context,
              title: "Couldn't save the return time",
              lines: ['Check your internet connection and try again.'],
              type: NoticeType.error);
        }
        return;
      }
      if (!mounted) return;
      await _load();
    } else {
      _updateAppOnly(rental.id, (r) => r.markedReturned(at));
    }
    if (!mounted) return;
    showTopNotice(context,
        title: '${rental.vehicleName} back at ${formatClock(at)}',
        lines: ['Tap End when you are ready to check it.'],
        type: NoticeType.success);
  }

  /// Opens O6. If the owner ends the rental, O6 returns true and the
  /// row is removed from "Active".
  Future<void> _openEnd(OwnerRental rental) async {
    final ended = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EndRentalScreen(rental: rental)),
    );
    if (ended != true || !mounted) return;
    if (rental.fromDatabase) {
      await _load(); // the database now says 'completed'
    } else {
      setState(
          () => _appOnly = _appOnly.where((r) => r.id != rental.id).toList());
    }
  }

  /// Opens O3b. When a booking is scanned (or its code typed), O3b returns
  /// it and Start rental (O5) opens for it.
  Future<void> _openScan() async {
    final rental = await Navigator.of(context).push<OwnerRental>(
      MaterialPageRoute(builder: (_) => ScanBookingScreen(rentals: _rentals)),
    );
    if (rental == null || !mounted) return;
    await _openStart(rental);
  }

  /// Shown instead of the three lists while loading or after an error.
  Widget? _status() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.dark)),
      );
    }
    if (_loadFailed && _dbRentals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text("Couldn't load bookings",
                style: inter(15, weight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Check your internet connection.',
                style: inter(13, color: AppColors.text2)),
            const SizedBox(height: 12),
            SmallButton(label: 'Try again', onPressed: _load),
          ],
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final waiting = _withStatus(['pending_payment']);
    final ready = _withStatus(['ready', 'checked_in']);
    final active = _withStatus(['active']);
    final status = _status();

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
      body: RefreshIndicator(
        color: AppColors.dark,
        onRefresh: AppConfig.uiPreviewMode ? () async {} : _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _openScan, // O3b
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
            if (status != null)
              status
            else ...[
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

              // ---- Active -> O6 ----
              const SectionTitle('Active'),
              for (final r in active)
                _RentalRow(
                  title: r.title,
                  subtitle: _activeLine(r, now),
                  badge: r.isReturned
                      ? const RentalBadge('RETURNED', filled: false)
                      : (r.isWalkIn && r.minutesLate(now) > 0
                          ? const RentalBadge('OVERDUE')
                          : null),
                  // Step 1: "Returned" the moment the vehicle arrives (saves the time).
                  // Step 2: "End" to check condition and charges on O6.
                  button: r.isReturned
                      ? SmallButton(
                          label: 'End',
                          onPressed: () => _openEnd(r), // O6
                        )
                      : SmallButton(
                          label: 'Returned',
                          primary: false,
                          onPressed: () => _markReturned(r),
                        ),
                  onTap: () => _openEnd(r), // O6
                ),
              if (active.isEmpty) const _EmptyRow(),
            ],
          ],
        ),
      ),
    );
  }

  /// Second line of an active row, e.g. "+0:10 late · 1 block auto-charged".
  String _activeLine(OwnerRental r, DateTime now) {
    if (r.isReturned) return _returnedLine(r);
    final late = r.minutesLate(now);
    if (late == 0) return 'Until ${formatClock(r.scheduledEnd)}';
    if (r.isWalkIn) {
      return '${formatLate(late)} overdue · extra ${formatRM(r.lateCharge(now))} · not tracked';
    }
    final blocks = r.lateBlocks(now);
    if (blocks == 0) return '${formatLate(late)} late · in grace period';
    // Real bookings: no automatic card charge yet, so the late charge is
    // collected when the rental ends.
    if (r.fromDatabase) {
      return '${formatLate(late)} late · ${_blocks(blocks)} · ${formatRM(r.lateCharge(now))}';
    }
    return '${formatLate(late)} late · ${_blocks(blocks)} auto-charged';
  }

  /// Second line once "Returned" was tapped: the time is frozen there,
  /// e.g. "Back 3:34 pm · on time" or "Back 3:40 pm · +0:10 late".
  String _returnedLine(OwnerRental r) {
    final at = r.returnedAt!;
    final back = 'Back ${formatClock(at)}';
    final late = r.minutesLate(at);
    if (late == 0) return '$back · on time · tap End to check';
    final blocks = r.lateBlocks(at);
    if (blocks == 0) return '$back · ${formatLate(late)} late (grace)';
    if (r.isWalkIn || r.fromDatabase) {
      return '$back · ${formatLate(late)} late · ${formatRM(r.lateCharge(at))} to collect';
    }
    return '$back · ${formatLate(late)} late · ${_blocks(blocks)} charged';
  }

  /// "1 late block" / "3 late blocks".
  String _blocks(int n) => '$n late block${n == 1 ? '' : 's'}';
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
          border:
              Border(bottom: BorderSide(color: AppColors.divider, width: 1.5)),
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
