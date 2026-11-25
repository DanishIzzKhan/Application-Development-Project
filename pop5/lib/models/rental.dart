import 'dart:math';
import 'dart:typed_data';

import 'vehicle.dart';

/// Owner-side view of one rental (O3, O5, O6, ...).
/// Field names follow the `rentals` table in supabase/migrations.
class OwnerRental {
  static const blockMinutes = 20; // rentals are booked in 20-minute blocks
  static const graceMinutes = 5; // free minutes after the end time

  final String id;
  final String bookingCode; // rentals.booking_code, 8 characters e.g. 3F9A1C2B

  /// rentals.qr_token: the long secret inside the customer's booking QR.
  /// O3b scans it to find this booking. Walk-ins have none (no QR).
  final String? qrToken;
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

  // ---------- Only for bookings loaded from Supabase ----------

  /// True = this booking is a row in the `rentals` table (real data).
  /// False = sample data or a walk-in only kept in the app for now.
  final bool fromDatabase;
  final String? customerId; // rentals.customer_id (app customers)

  /// Storage paths of the IC photos in the private ic-documents bucket:
  /// the app customer's (users.ic_front_path / ic_back_path) or the
  /// walk-in's (rentals.walk_in_ic_front_path / walk_in_ic_back_path).
  final String? icFrontPath;
  final String? icBackPath;

  /// rentals.late_blocks_charged: late blocks really auto-charged so far.
  final int lateBlocksCharged;

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
    this.qrToken,
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
    this.fromDatabase = false,
    this.customerId,
    this.icFrontPath,
    this.icBackPath,
    this.lateBlocksCharged = 0,
  });

  /// One row of `rentals` from Supabase, joined with `vehicles(id, type)` and
  /// `users(username, full_name, ic_front_path, ic_back_path)`.
  /// [upfront] is the booking's completed upfront payment, if any
  /// (payment_method, gateway_ref): a gateway_ref means it was paid online.
  factory OwnerRental.fromMap(Map<String, dynamic> m,
      {Map<String, dynamic>? upfront}) {
    final v = m['vehicles'] as Map?;
    final u = m['users'] as Map?;
    final walkIn = m['is_walk_in'] == true;
    final status = m['status'] as String;
    final rate = (m['rate_per_block_at_booking'] as num).toDouble();
    final lateRate = (m['late_rate_at_booking'] as num?)?.toDouble() ?? 0;
    DateTime? time(String key) =>
        m[key] == null ? null : DateTime.parse(m[key] as String).toLocal();

    final frontPath = walkIn
        ? m['walk_in_ic_front_path'] as String?
        : u?['ic_front_path'] as String?;
    final backPath = walkIn
        ? m['walk_in_ic_back_path'] as String?
        : u?['ic_back_path'] as String?;

    return OwnerRental(
      id: m['id'] as String,
      bookingCode: (m['booking_code'] as String).toUpperCase(),
      qrToken: m['qr_token'] as String?,
      vehicleName: _vehicleName(v),
      customerName: walkIn
          ? 'Walk-in: ${m['walk_in_name'] ?? 'customer'}'
          : (u?['username'] ?? u?['full_name'] ?? 'customer').toString(),
      isWalkIn: walkIn,
      status: status,
      blocksBooked: (m['blocks_booked'] as num).toInt(),
      ratePerBlock: rate,
      // Locked in when the rental starts; before that, the normal price.
      lateRatePerBlock: lateRate > 0 ? lateRate : rate,
      isPaid: status != 'pending_payment',
      paidOnline: upfront?['gateway_ref'] != null,
      paymentMethod: upfront?['payment_method'] as String?,
      scheduledStart: time('scheduled_start_time')!,
      scheduledEnd: time('scheduled_end_time')!,
      depositNote: m['deposit_note'] as String?,
      walkInPhone: m['walk_in_phone'] as String?,
      walkInIcPhotoTaken: walkIn && (frontPath != null || backPath != null),
      // "Returned" saves actual_end_time while the rental is still active.
      returnedAt: status == 'active' ? time('actual_end_time') : null,
      fromDatabase: true,
      customerId: m['customer_id'] as String?,
      icFrontPath: frontPath,
      icBackPath: backPath,
      lateBlocksCharged: (m['late_blocks_charged'] as num?)?.toInt() ?? 0,
    );
  }

  /// Same naming as Vehicle.name: "Scooter S01", or just the id when it
  /// already starts with the type.
  static String _vehicleName(Map? v) {
    if (v == null) return 'Vehicle';
    final id = '${v['id']}';
    final type = '${v['type']}';
    return id.toLowerCase().startsWith(type.toLowerCase()) ? id : '$type $id';
  }

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
    // Sample code until the Api makes one: 8 hex characters like the database.
    final code = Random()
        .nextInt(0x7FFFFFFF)
        .toRadixString(16)
        .toUpperCase()
        .padLeft(8, '0');
    return OwnerRental(
      id: 'RNT-$code',
      bookingCode: code,
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

  /// Late blocks = round up ((minutes late − 5) ÷ 20). No upper limit:
  /// a new block is charged every 20 minutes until the vehicle is back.
  /// Inside the 5-minute grace period there is no charge.
  static int lateBlocksFor(int minutesLate) {
    if (minutesLate <= graceMinutes) return 0;
    return ((minutesLate - graceMinutes) / blockMinutes).ceil();
  }

  int lateBlocks(DateTime now) => lateBlocksFor(minutesLate(now));
  double lateCharge(DateTime now) => lateBlocks(now) * lateRatePerBlock;

  /// Late blocks already auto-charged to the saved card by [now].
  /// Walk-ins have no saved card, so nothing is auto-charged.
  /// Auto-charging stops once the owner taps "Returned".
  /// Real bookings: rentals.late_blocks_charged from the database.
  /// Sample data: assumes the auto-charge ran on time.
  int autoChargedBlocks(DateTime now) {
    if (isWalkIn) return 0;
    if (fromDatabase) return lateBlocksCharged;
    return lateBlocks(returnedAt ?? now);
  }

  // ---------- Status changes kept in the app (sample data / walk-ins) ----------

  /// Copy of this rental after the owner taps "Returned" on O3.
  OwnerRental markedReturned(DateTime at) => OwnerRental(
        id: id,
        bookingCode: bookingCode,
        qrToken: qrToken,
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
        fromDatabase: fromDatabase,
        customerId: customerId,
        icFrontPath: icFrontPath,
        icBackPath: icBackPath,
        lateBlocksCharged: lateBlocksCharged,
      );

  /// Copy of this rental after the owner taps "Start rental" on O5:
  /// the timer starts now and runs for the booked duration.
  OwnerRental startedAt(DateTime now) => OwnerRental(
        id: id,
        bookingCode: bookingCode,
        qrToken: qrToken,
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
        fromDatabase: fromDatabase,
        customerId: customerId,
        icFrontPath: icFrontPath,
        icBackPath: icBackPath,
        lateBlocksCharged: lateBlocksCharged,
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
  String? qr,
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
      qrToken: qr,
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
        code: '3F9A1C2B',
        qr: 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
        v: _scootS01,
        customer: 'ahmad_rides',
        status: 'pending_payment',
        blocks: 3,
        start: t),
    // Ready for handover, paid online: 3 × RM 10 = RM 30.00
    _sample(
        id: 'RNT-8802',
        code: '7C4E0B19',
        qr: 'b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1',
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
        code: 'D05A6E3F',
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
        code: '9B21F7A4',
        qr: 'c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2',
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
        code: 'E8136C5D',
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
