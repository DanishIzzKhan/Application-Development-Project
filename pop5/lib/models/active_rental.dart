/// One row of `rentals` (joined with `vehicles`) plus the time / late-charge maths
/// used by C9, C9b, C9c, C9d and C10.
class ActiveRental {
  final String id;
  final String vehicleName; // e.g. "Bicycle BK-01"
  final String status;
  final DateTime start; // scheduled_start_time
  final DateTime end; // scheduled_end_time (moves when extended)
  final DateTime? actualEnd; // actual_end_time (set when returned)
  final int blocks; // blocks_booked (20 minutes each)
  final int graceMinutes; // grace_minutes_at_booking
  final double lateRate; // late_rate_at_booking
  final double ratePerBlock; // rate_per_block_at_booking
  final int lateBlocksCharged; // late_blocks_charged
  final double total; // total_amount

  const ActiveRental({
    required this.id,
    required this.vehicleName,
    required this.status,
    required this.start,
    required this.end,
    required this.actualEnd,
    required this.blocks,
    required this.graceMinutes,
    required this.lateRate,
    required this.ratePerBlock,
    required this.lateBlocksCharged,
    required this.total,
  });

  /// Needs the select: `*, vehicles(id, type)`.
  factory ActiveRental.fromMap(Map<String, dynamic> m) {
    final v = m['vehicles'];
    DateTime t(Object? s) => DateTime.parse('$s').toLocal();
    return ActiveRental(
      id: m['id'] as String,
      vehicleName: v == null ? 'Vehicle' : '${v['type']} ${v['id']}',
      status: m['status'] as String,
      start: t(m['scheduled_start_time']),
      end: t(m['scheduled_end_time']),
      actualEnd: m['actual_end_time'] == null ? null : t(m['actual_end_time']),
      blocks: (m['blocks_booked'] as num).toInt(),
      graceMinutes: (m['grace_minutes_at_booking'] as num).toInt(),
      lateRate: (m['late_rate_at_booking'] as num).toDouble(),
      ratePerBlock: (m['rate_per_block_at_booking'] as num).toDouble(),
      lateBlocksCharged: (m['late_blocks_charged'] as num).toInt(),
      total: (m['total_amount'] as num).toDouble(),
    );
  }

  Duration get bookedDuration => Duration(minutes: blocks * 20);

  Duration timeLeft(DateTime now) => end.difference(now);

  /// How long past the end time (zero if not late). Uses the return time once returned.
  Duration lateBy(DateTime now) {
    final d = (actualEnd ?? now).difference(end);
    return d.isNegative ? Duration.zero : d;
  }

  /// Late blocks after the free grace period: 25 min late with 5 min free = 1 block.
  int lateBlocks(DateTime now) {
    final late = lateBy(now).inSeconds / 60.0;
    if (late <= graceMinutes) return 0;
    return ((late - graceMinutes) / 20).ceil();
  }

  double lateCharge(DateTime now) => lateBlocks(now) * lateRate;

  /// When the next late block will be charged.
  DateTime nextChargeAt(DateTime now) =>
      end.add(Duration(minutes: graceMinutes + lateBlocks(now) * 20));
}

/// "RM 3.00", or "RM X" while the owner has not set a late rate yet.
String rmOrX(double v) => v > 0 ? 'RM ${v.toStringAsFixed(2)}' : 'RM X';

/// 3:05 PM
String clockLabel(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour >= 12 ? 'PM' : 'AM';
  return '$h12:${t.minute.toString().padLeft(2, '0')} $ampm';
}