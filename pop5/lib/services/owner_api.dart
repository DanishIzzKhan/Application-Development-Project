import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/rental.dart';
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
