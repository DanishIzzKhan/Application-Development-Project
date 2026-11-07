/// Owner-side view of one rental (O3, O5, O6, ...).
/// Field names follow the `rentals` table in supabase/migrations.
class OwnerRental {
  static const blockMinutes = 20; // rentals are booked in 20-minute blocks
  static const graceMinutes = 5; // free minutes after the end time
  static const maxAutoLateBlocks = 3; // stop auto-charging after 3 blocks

  final String id;
  final String bookingCode; // e.g. ISY-4821
  final String vehicleName; // e.g. "Scooter S01"
  final String customerName; // username, or the walk-in name
  final bool isWalkIn;
  final String status; // 'pending_payment' | 'ready' | 'active'
  final int blocksBooked;
  final double ratePerBlock;
  final double lateRatePerBlock;
  final bool isPaid;
  final bool paidOnline; // true = paid in the app, false = at the counter
  final DateTime scheduledStart;
  final DateTime scheduledEnd;
  final String? depositNote; // walk-ins only, e.g. "IC copy"
  final bool walkInIcPhotoTaken; // walk-ins only: IC photo taken on O4

  const OwnerRental({
    required this.id,
    required this.bookingCode,
    required this.vehicleName,
    required this.customerName,
    required this.status,
    required this.blocksBooked,
    required this.ratePerBlock,
    required this.lateRatePerBlock,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.isWalkIn = false,
    this.isPaid = false,
    this.paidOnline = false,
    this.depositNote,
    this.walkInIcPhotoTaken = false,
  });

  // ---------- Booking ----------

  int get durationMinutes => blocksBooked * blockMinutes;
  double get rentalTotal => blocksBooked * ratePerBlock;

  /// "1 hr 0 min"
  String get durationLabel => formatDuration(durationMinutes);
  String get totalLabel => formatRM(rentalTotal);

  /// "Scooter S01 · ahmad_rides"
  String get title => '$vehicleName · $customerName';

  /// "now" if the booking starts within 5 minutes, otherwise the clock time.
  String startLabel(DateTime now) =>
      scheduledStart.difference(now).inMinutes.abs() <= 5
          ? 'now'
          : formatClock(scheduledStart);

  // ---------- Late charge maths ----------

  /// Minutes past the booked end time (0 if not late yet).
  int minutesLate(DateTime now) {
    final m = now.difference(scheduledEnd).inMinutes;
    return m > 0 ? m : 0;
  }

  /// Late blocks = round up ((minutes late − 5) ÷ 20), capped at 3.
  /// Inside the 5-minute grace period there is no charge.
  static int lateBlocksFor(int minutesLate) {
    if (minutesLate <= graceMinutes) return 0;
    final blocks = ((minutesLate - graceMinutes) / blockMinutes).ceil();
    return blocks > maxAutoLateBlocks ? maxAutoLateBlocks : blocks;
  }

  int lateBlocks(DateTime now) => lateBlocksFor(minutesLate(now));
  double lateCharge(DateTime now) => lateBlocks(now) * lateRatePerBlock;

  // ---------- Status changes (sample data only, until Api exists) ----------

  /// Copy of this rental after the owner taps "Start rental" on O5:
  /// the timer starts now and runs for the booked duration.
  OwnerRental startedAt(DateTime now) => OwnerRental(
        id: id,
        bookingCode: bookingCode,
        vehicleName: vehicleName,
        customerName: customerName,
        isWalkIn: isWalkIn,
        status: 'active',
        blocksBooked: blocksBooked,
        ratePerBlock: ratePerBlock,
        lateRatePerBlock: lateRatePerBlock,
        isPaid: true,
        paidOnline: paidOnline,
        scheduledStart: now,
        scheduledEnd: now.add(Duration(minutes: durationMinutes)),
        depositNote: depositNote,
        walkInIcPhotoTaken: walkInIcPhotoTaken,
      );
}

// ---------- Formatting helpers ----------

String formatRM(double amount) => 'RM ${amount.toStringAsFixed(2)}';

/// 60 -> "1 hr 0 min", 40 -> "40 min"
String formatDuration(int minutes) =>
    minutes >= 60 ? '${minutes ~/ 60} hr ${minutes % 60} min' : '$minutes min';

/// 10 -> "+0:10"
String formatLate(int minutes) =>
    '+${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

/// 15:00 -> "3:00 pm"
String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ampm = t.hour >= 12 ? 'pm' : 'am';
  return '$h:${t.minute.toString().padLeft(2, '0')} $ampm';
}

// ---------- Sample data (AppConfig.uiPreviewMode) ----------

/// Rentals shown on O3 before Supabase is connected.
/// Times are relative to [now] so the late rows are always late.
List<OwnerRental> sampleOwnerRentals([DateTime? now]) {
  final t = now ?? DateTime.now();
  return [
    OwnerRental(
      id: 'RNT-8801',
      bookingCode: 'ISY-4821',
      vehicleName: 'Scooter S01',
      customerName: 'ahmad_rides',
      status: 'pending_payment',
      blocksBooked: 3,
      ratePerBlock: 5,
      lateRatePerBlock: 5,
      scheduledStart: t,
      scheduledEnd: t.add(const Duration(minutes: 60)),
    ),
    OwnerRental(
      id: 'RNT-8802',
      bookingCode: 'ISY-4822',
      vehicleName: 'Bicycle B02',
      customerName: 'ahmad_rides',
      status: 'ready',
      blocksBooked: 3,
      ratePerBlock: 3,
      lateRatePerBlock: 3,
      isPaid: true,
      paidOnline: true,
      scheduledStart: t,
      scheduledEnd: t.add(const Duration(minutes: 60)),
    ),
    // Walk-in booked on O4: paid at the counter, IC photo already taken.
    OwnerRental(
      id: 'RNT-8803',
      bookingCode: 'ISY-4823',
      vehicleName: 'Bicycle B05',
      customerName: 'Walk-in: Siti',
      isWalkIn: true,
      status: 'ready',
      blocksBooked: 2,
      ratePerBlock: 3,
      lateRatePerBlock: 3,
      isPaid: true,
      depositNote: 'IC copy',
      walkInIcPhotoTaken: true,
      scheduledStart: t,
      scheduledEnd: t.add(const Duration(minutes: 40)),
    ),
    OwnerRental(
      id: 'RNT-8790',
      bookingCode: 'ISY-4790',
      vehicleName: 'Scooter S02',
      customerName: 'mei_ling',
      status: 'active',
      blocksBooked: 3,
      ratePerBlock: 5,
      lateRatePerBlock: 5,
      isPaid: true,
      paidOnline: true,
      scheduledStart: t.subtract(const Duration(minutes: 70)),
      scheduledEnd: t.subtract(const Duration(minutes: 10)),
    ),
    OwnerRental(
      id: 'RNT-8791',
      bookingCode: 'ISY-4791',
      vehicleName: 'Bicycle B04',
      customerName: 'Walk-in: Ali',
      isWalkIn: true,
      status: 'active',
      blocksBooked: 3,
      ratePerBlock: 3,
      lateRatePerBlock: 3,
      isPaid: true,
      depositNote: 'IC copy',
      walkInIcPhotoTaken: true,
      scheduledStart: t.subtract(const Duration(minutes: 70)),
      scheduledEnd: t.subtract(const Duration(minutes: 10)),
    ),
  ];
}

/// Condition chips on O5 (collection) and O6 (return).
enum VehicleCondition {
  good('Good'),
  minorIssue('Minor issue'),
  damaged('Damaged');

  final String label;
  const VehicleCondition(this.label);
}
