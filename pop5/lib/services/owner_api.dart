import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer.dart';
import '../models/rental.dart';
import '../models/vehicle.dart';
import 'api.dart';

/// Owner-side calls to Supabase (rentals, counter payment, start, returned).
/// The database functions check that the signed-in user has role 'owner'.
class OwnerApi {
  static final _hex = RegExp(r'^[0-9a-fA-F]{8,64}$');

  /// Columns O3 / O5 need: the booking, its vehicle and the app customer.
  static const _rentalSelect =
      '*, vehicles(id, type), users(username, full_name, ic_front_path, ic_back_path)';

  // ---------- O3 Rentals ----------

  /// Bookings the owner still has to handle: waiting for payment, ready for
  /// handover, and active. Oldest start time first.
  static Future<List<OwnerRental>> fetchOpenRentals() async {
    final rows = await supabase.from('rentals').select(_rentalSelect).inFilter(
        'status', [
      'pending_payment',
      'ready',
      'checked_in',
      'active'
    ]).order('scheduled_start_time');
    final upfront =
        await _upfrontPayments([for (final r in rows) r['id'] as String]);
    return [
      for (final r in rows) OwnerRental.fromMap(r, upfront: upfront[r['id']]),
    ];
  }

  /// One booking, freshly loaded (e.g. when Start rental opens).
  static Future<OwnerRental> fetchRental(String rentalId) async {
    final row = await supabase
        .from('rentals')
        .select(_rentalSelect)
        .eq('id', rentalId)
        .single();
    final upfront = await _upfrontPayments([rentalId]);
    return OwnerRental.fromMap(row, upfront: upfront[rentalId]);
  }

  /// The completed upfront payment of each booking: {rental id: payment}.
  /// Read separately so a missing payment never hides a booking.
  static Future<Map<String, Map<String, dynamic>>> _upfrontPayments(
      List<String> rentalIds) async {
    if (rentalIds.isEmpty) return {};
    final rows = await supabase
        .from('payments')
        .select('rental_id, payment_method, gateway_ref')
        .inFilter('rental_id', rentalIds)
        .eq('payment_type', 'upfront')
        .eq('status', 'completed');
    return {for (final p in rows) p['rental_id'] as String: p};
  }

  // ---------- O3b Scan booking ----------

  /// Finds a booking from a scanned QR (qr_token, 64 hex characters) or a typed
  /// booking code (8 hex characters). Returns {id, status} or null.
  static Future<Map<String, dynamic>?> findRental(String value) async {
    final v = value.trim();
    if (!_hex.hasMatch(v)) return null; // not one of our codes
    final rows = await supabase
        .from('rentals')
        .select('id, status')
        .or('qr_token.eq.$v,booking_code.eq.${v.toUpperCase()}')
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  // ---------- O5 Start rental ----------

  /// [method] is 'Cash', 'TnG' or 'Bank QR'. Moves pending_payment -> ready.
  static Future<void> confirmPayment(String rentalId, String method) async {
    await supabase.rpc('owner_confirm_payment',
        params: {'p_rental_id': rentalId, 'p_method': method});
  }

  /// [condition] is 'Good', 'Minor issue' or 'Damaged'. Moves ready -> active.
  static Future<void> startRental(String rentalId, String condition) async {
    await supabase.rpc('owner_start_rental',
        params: {'p_rental_id': rentalId, 'p_condition': condition});
  }

  // ---------- O3 "Returned" ----------

  /// Saves the return time now and stops late auto-charging.
  static Future<void> markReturned(String rentalId) async {
    await supabase
        .rpc('owner_mark_returned', params: {'p_rental_id': rentalId});
  }

  // ---------- O4 Walk-in ----------

  /// Vehicles the owner can hand to a walk-in right now.
  static Future<List<Vehicle>> fetchAvailableVehicles() async {
    final rows = await supabase
        .from('vehicles')
        .select()
        .eq('is_active', true)
        .eq('status', 'Available')
        .order('id');
    return [for (final m in rows) Vehicle.fromMap(m)];
  }

  /// Creates a walk-in booking starting now and returns it ready to start:
  ///   1. rentals row (is_walk_in, name, phone, not tracked on the map);
  ///      the database trigger sets the price, end time and booking code
  ///   2. optional IC photos -> ic-documents/walk-in/<rental id>/
  ///   3. counter payment -> owner_confirm_payment (status -> ready)
  static Future<OwnerRental> createWalkIn({
    required String name,
    required String phone,
    required Vehicle vehicle,
    required int minutes,
    required String method, // 'Cash' | 'TnG' | 'Bank QR'
    Uint8List? icFront,
    Uint8List? icBack,
  }) async {
    final row = await supabase
        .from('rentals')
        .insert({
          'vehicle_id': vehicle.id,
          'scheduled_start_time': DateTime.now().toUtc().toIso8601String(),
          'blocks_booked': minutes ~/ OwnerRental.blockMinutes,
          'is_walk_in': true,
          'walk_in_name': name,
          'walk_in_phone': phone,
          'is_tracked': false,
        })
        .select('id')
        .single();
    final id = row['id'] as String;

    // IC photos are optional; only the owner may write to walk-in/.
    final paths = <String, String>{};
    final bucket = supabase.storage.from('ic-documents');
    for (final (side, bytes) in [('front', icFront), ('back', icBack)]) {
      if (bytes == null) continue;
      final path = 'walk-in/$id/$side.jpg';
      await bucket.uploadBinary(path, bytes,
          fileOptions:
              const FileOptions(upsert: true, contentType: 'image/jpeg'));
      paths['walk_in_ic_${side}_path'] = path;
    }
    if (paths.isNotEmpty) {
      await supabase.from('rentals').update(paths).eq('id', id);
    }

    await confirmPayment(id, method);
    return fetchRental(id);
  }

  // ---------- O3c Customer details ----------

  /// The customer of [r]: app customers from `users`, walk-ins from the
  /// name / phone on the booking. History = their finished rentals, newest
  /// first, marked LATE (past the free minutes) or ISSUE (not returned Good).
  static Future<CustomerProfile> fetchCustomer(OwnerRental r) async {
    if (r.isWalkIn) {
      final phone = r.walkInPhone ?? '';
      final past = phone.isEmpty
          ? <Map<String, dynamic>>[]
          : await supabase
              .from('rentals')
              .select(_historySelect)
              .eq('is_walk_in', true)
              .eq('walk_in_phone', phone)
              .eq('status', 'completed')
              .order('scheduled_start_time', ascending: false)
              .limit(20);
      return CustomerProfile(
        displayName: r.customerName.replaceFirst('Walk-in: ', ''),
        phone: phone.isEmpty ? '-' : phone,
        isWalkIn: true,
        rentalCount: past.length,
        history: await _history(past),
      );
    }

    final u =
        await supabase.from('users').select().eq('id', r.customerId!).single();
    final past = await supabase
        .from('rentals')
        .select(_historySelect)
        .eq('customer_id', r.customerId!)
        .eq('status', 'completed')
        .order('scheduled_start_time', ascending: false)
        .limit(20);
    return CustomerProfile(
      displayName: (u['username'] ?? u['full_name'] ?? 'customer').toString(),
      fullName: u['full_name'] as String?,
      phone: (u['phone'] ?? '-').toString(),
      email: u['email'] as String?,
      since: u['created_at'] == null
          ? null
          : DateTime.parse(u['created_at'] as String).toLocal(),
      rentalCount: past.length,
      history: await _history(past),
    );
  }

  static const _historySelect = 'id, scheduled_start_time, scheduled_end_time, '
      'actual_end_time, grace_minutes_at_booking, vehicles(id, type)';

  static Future<List<PastRental>> _history(
      List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    // Rentals where the vehicle came back with a problem.
    final checks = await supabase
        .from('vehicle_condition_checks')
        .select('rental_id, condition, notes')
        .inFilter('rental_id', [for (final r in rows) r['id'] as String])
        .eq('stage', 'return')
        .neq('condition', 'Good');
    final issues = {for (final c in checks) c['rental_id'] as String: c};

    return [
      for (final r in rows) _pastRental(r, issues[r['id']]),
    ];
  }

  static PastRental _pastRental(
      Map<String, dynamic> r, Map<String, dynamic>? issue) {
    final v = r['vehicles'] as Map?;
    final title = v == null ? 'Vehicle' : _vehicleTitle(v);
    final start = DateTime.parse(r['scheduled_start_time'] as String).toLocal();
    final end = DateTime.parse(r['scheduled_end_time'] as String);
    final back = r['actual_end_time'] == null
        ? end
        : DateTime.parse(r['actual_end_time'] as String);
    final lateMin = back.difference(end).inMinutes;
    final grace = (r['grace_minutes_at_booking'] as num?)?.toInt() ?? 5;
    final date = formatDate(start);

    if (issue != null) {
      final note = (issue['notes'] ?? issue['condition']).toString();
      return PastRental(title, '$date · reported: $note', badge: 'ISSUE');
    }
    if (lateMin > grace) {
      return PastRental(title, '$date · returned $lateMin min late',
          badge: 'LATE');
    }
    return PastRental(title, '$date · returned on time');
  }

  static String _vehicleTitle(Map v) {
    final id = '${v['id']}';
    final type = '${v['type']}';
    return id.toLowerCase().startsWith(type.toLowerCase()) ? id : '$type $id';
  }

  // ---------- O6 End rental ----------

  /// Uploads the photo of an issue found at return to the report-photos
  /// bucket, in the owner's own folder (same rule as customer reports).
  /// Returns the storage path saved with the condition check.
  static Future<String> uploadIssuePhoto(
      String rentalId, Uint8List bytes) async {
    final uid = supabase.auth.currentUser!.id;
    final path = '$uid/$rentalId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await supabase.storage.from('report-photos').uploadBinary(path, bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg'));
    return path;
  }

  /// Ends the rental with owner_end_rental: return time, condition (+ issue),
  /// waiver and, for late blocks not auto-charged, the counter payment
  /// [method] ('Cash' | 'TnG' | 'Bank QR' | 'Card'). Rental -> completed,
  /// vehicle -> Available (Maintenance if damaged).
  static Future<void> endRental(
    String rentalId, {
    required DateTime returnTime,
    required String condition,
    String? issueNote,
    String? issuePhotoPath,
    bool waive = false,
    String? method,
  }) async {
    await supabase.rpc('owner_end_rental', params: {
      'p_rental_id': rentalId,
      'p_return_time': returnTime.toUtc().toIso8601String(),
      'p_condition': condition,
      'p_issue_note': issueNote,
      'p_issue_photo': issuePhotoPath,
      'p_waive': waive,
      'p_payment_method': method,
    });
  }

  // ---------- IC photos ----------

  /// Records that the owner opened an IC (ic_access_log), then downloads
  /// the photos from the private bucket. Nothing is shown if logging fails.
  static Future<({Uint8List? front, Uint8List? back})> openIc(
      OwnerRental r) async {
    await supabase.from('ic_access_log').insert({
      'customer_id': r.customerId,
      'rental_id': r.id,
    });
    return (
      front: await downloadIc(r.icFrontPath),
      back: await downloadIc(r.icBackPath),
    );
  }

  /// Downloads an IC photo from the private bucket (owners may read all).
  static Future<Uint8List?> downloadIc(Object? path) async {
    if (path == null) return null;
    return supabase.storage.from('ic-documents').download(path as String);
  }
}
