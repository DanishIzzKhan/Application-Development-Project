import 'dart:math';
import 'dart:typed_data';

import 'vehicle.dart';

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

  /// The walk-in's IC photos from O4, front and back (kept in memory for now).
  /// Later: uploaded to the private ic-documents bucket, paths on the rental.
  final Uint8List? walkInIcFront;
  final Uint8List? walkInIcBack;
  final String? walkInPhone; // walk-ins only (rentals.walk_in_phone)
  final String?
      paymentMethod; // 'Cash' | 'TnG' | 'Bank QR' | 'Card' (payments table)

  /// When the owner tapped "Returned" on O3 (vehicle physically back).
  /// O6 uses it as the actual return time. Null = not back yet.
  final DateTime? returnedAt;

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
    this.walkInIcFront,
    this.walkInIcBack,
    this.walkInPhone,
    this.paymentMethod,
    this.returnedAt,
  });

  bool get isReturned => returnedAt != null;

  /// New walk-in booking made by the owner on O4.
  /// Paid at the counter, not tracked on the map, waiting for handover (O5).
  factory OwnerRental.newWalkIn({
    required String name,
    required String phone,
    required Vehicle vehicle,
    required int minutes,
    required String paymentMethod,
    Uint8List? icFront,
    Uint8List? icBack,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final n =
        Random().nextInt(9000) + 1000; // sample code until the Api makes one
    return OwnerRental(
      id: 'RNT-$n',
      bookingCode: 'ISY-$n',
      vehicleName: vehicle.name,
      customerName: 'Walk-in: $name',
      isWalkIn: true,
      status: 'ready',
      blocksBooked: minutes ~/ blockMinutes,
      ratePerBlock: vehicle.pricePer20Min,
      lateRatePerBlock: vehicle.pricePer20Min,
      isPaid: true,
      scheduledStart: t,
      scheduledEnd: t.add(Duration(minutes: minutes)),
      walkInIcPhotoTaken: icFront != null || icBack != null,
      walkInIcFront: icFront,
      walkInIcBack: icBack,
      walkInPhone: phone,
      paymentMethod: paymentMethod,
    );
  }

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

  /// Late blocks already auto-charged to the saved card by [now].
  /// Walk-ins have no saved card, so nothing is auto-charged.
  /// Auto-charging stops once the owner taps "Returned".
  /// Sample data: assumes the auto-charge ran on time.
  /// Later: rentals.late_blocks_charged from the database.
  int autoChargedBlocks(DateTime now) =>
      isWalkIn ? 0 : lateBlocks(returnedAt ?? now);

  // ---------- Status changes (sample data only, until Api exists) ----------

  /// Copy of this rental after the owner taps "Returned" on O3.
  OwnerRental markedReturned(DateTime at) => OwnerRental(
        id: id,
        bookingCode: bookingCode,
        vehicleName: vehicleName,
        customerName: customerName,
        isWalkIn: isWalkIn,
        status: status,
        blocksBooked: blocksBooked,
        ratePerBlock: ratePerBlock,
        lateRatePerBlock: lateRatePerBlock,
        isPaid: isPaid,
        paidOnline: paidOnline,
        scheduledStart: scheduledStart,
        scheduledEnd: scheduledEnd,
        depositNote: depositNote,
        walkInIcPhotoTaken: walkInIcPhotoTaken,
        walkInIcFront: walkInIcFront,
        walkInIcBack: walkInIcBack,
        walkInPhone: walkInPhone,
        paymentMethod: paymentMethod,
        returnedAt: at,
      );

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
        walkInIcFront: walkInIcFront,
        walkInIcBack: walkInIcBack,
        walkInPhone: walkInPhone,
        paymentMethod: paymentMethod,
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

/// Real ISYGEAR prices per 20-minute block (RM).
/// The late charge per block is the same as the vehicle's block price.
class ShopPrices {
  static const roadBike = 10.0;
  static const mtbBmxKids = 10.0; // MTB, BMX and kids bikes
  static const pushBike = 5.0;
  static const scooter = 10.0;
}

Vehicle _v(String id, String name, String type, double price) =>
    Vehicle(id: id, type: type, pricePer20Min: price, status: 'available');

/// Sample fleet. Each sample rental below uses one of these, so its price
/// always comes from the vehicle.
final _roadR01 = _v('R01', 'Road bike R01', 'bicycle', ShopPrices.roadBike);
final _roadR02 = _v('R02', 'Road bike R02', 'bicycle', ShopPrices.roadBike);
final _mtbM01 = _v('M01', 'MTB M01', 'bicycle', ShopPrices.mtbBmxKids);
final _mtbM02 = _v('M02', 'MTB M02', 'bicycle', ShopPrices.mtbBmxKids);
final _bmxX01 = _v('X01', 'BMX X01', 'bicycle', ShopPrices.mtbBmxKids);
final _kidsK01 = _v('K01', 'Kids bike K01', 'bicycle', ShopPrices.mtbBmxKids);
final _pushP01 = _v('P01', 'Push bike P01', 'bicycle', ShopPrices.pushBike);
final _scootS01 = _v('S01', 'Scooter S01', 'scooter', ShopPrices.scooter);
final _scootS02 = _v('S02', 'Scooter S02', 'scooter', ShopPrices.scooter);
final _scootS03 = _v('S03', 'Scooter S03', 'scooter', ShopPrices.scooter);

/// Vehicles free for a walk-in on O4 (not used by any sample rental).
List<Vehicle> sampleAvailableVehicles() =>
    [_roadR01, _mtbM01, _bmxX01, _pushP01, _scootS03];

/// One sample rental. Rate and late rate both come from [v]'s block price,
/// so the amount shown is always blocks × price.
OwnerRental _sample({
  required String id,
  required String code,
  required Vehicle v,
  required String customer,
  required String status,
  required int blocks,
  required DateTime start,
  bool walkIn = false,
  bool paid = false,
  bool online = false,
}) =>
    OwnerRental(
      id: id,
      bookingCode: code,
      vehicleName: v.name,
      customerName: customer,
      isWalkIn: walkIn,
      status: status,
      blocksBooked: blocks,
      ratePerBlock: v.pricePer20Min,
      lateRatePerBlock: v.pricePer20Min,
      isPaid: paid,
      paidOnline: online,
      paymentMethod: walkIn ? 'Cash' : null,
      walkInIcPhotoTaken: walkIn,
      scheduledStart: start,
      scheduledEnd:
          start.add(Duration(minutes: blocks * OwnerRental.blockMinutes)),
    );

/// Rentals shown on O3 before Supabase is connected.
/// Times are relative to [now] so the late rows are always late.
List<OwnerRental> sampleOwnerRentals([DateTime? now]) {
  final t = now ?? DateTime.now();
  final started70MinAgo = t.subtract(const Duration(minutes: 70));
  return [
    // Waiting for payment: 3 × RM 10 = RM 30.00
    _sample(
        id: 'RNT-8801',
        code: 'ISY-4821',
        v: _scootS01,
        customer: 'ahmad_rides',
        status: 'pending_payment',
        blocks: 3,
        start: t),
    // Ready for handover, paid online: 3 × RM 10 = RM 30.00
    _sample(
        id: 'RNT-8802',
        code: 'ISY-4822',
        v: _roadR02,
        customer: 'ahmad_rides',
        status: 'ready',
        blocks: 3,
        start: t,
        paid: true,
        online: true),
    // Ready for handover, walk-in paid cash: 2 × RM 10 = RM 20.00
    _sample(
        id: 'RNT-8803',
        code: 'ISY-4823',
        v: _kidsK01,
        customer: 'Walk-in: Siti',
        status: 'ready',
        blocks: 2,
        start: t,
        walkIn: true,
        paid: true),
    // Active, 10 min late: 1 late block × RM 10 auto-charged
    _sample(
        id: 'RNT-8790',
        code: 'ISY-4790',
        v: _scootS02,
        customer: 'mei_ling',
        status: 'active',
        blocks: 3,
        start: started70MinAgo,
        paid: true,
        online: true),
    // Active walk-in, 10 min overdue: extra 1 × RM 10
    _sample(
        id: 'RNT-8791',
        code: 'ISY-4791',
        v: _mtbM02,
        customer: 'Walk-in: Ali',
        status: 'active',
        blocks: 3,
        start: started70MinAgo,
        walkIn: true,
        paid: true),
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
