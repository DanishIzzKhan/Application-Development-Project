import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/registration_data.dart';
import '../models/vehicle.dart';

SupabaseClient get supabase => Supabase.instance.client;

class Api {
  // ---------- helpers ----------

  /// 012-345 6789 -> +60123456789
  static String normalizePhone(String raw) {
    final p = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0')) return '+6$p';
    if (p.startsWith('60')) return '+$p';
    return '+60$p';
  }

  // ---------- C1 login ----------

  /// [identifier] is a phone number or an email.
  static Future<void> _signIn(String identifier, String password) async {
    final id = identifier.trim();
    String email = id;
    if (!id.contains('@')) {
      final res = await supabase
          .rpc('get_email_by_phone', params: {'p_phone': normalizePhone(id)});
      if (res == null || (res as String).isEmpty) {
        throw const AuthException('No account found for this phone number.');
      }
      email = res;
    }
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  // ---------- C2 / C2b create account ----------

  static Future<void> sendPhoneCode(String phone) =>
      supabase.auth.signInWithOtp(phone: phone);

  static Future<void> verifyPhoneCode(String phone, String code) =>
      supabase.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);

  /// Creates the auth user, uploads both sides of the IC to the private
  /// `ic-documents` bucket and saves the profile row.
  static Future<void> _createAccount(
    RegistrationData d, {
    required XFile icFront,
    required XFile icBack,
  }) async {
    final meta = {
      'full_name': d.fullName,
      'username': d.username,
      'phone': d.phone,
    };

    if (d.phoneVerified) {
      // Already signed in through the SMS code: attach email + password.
      await supabase.auth.updateUser(
        UserAttributes(email: d.email, password: d.password, data: meta),
      );
    } else {
      final res = await supabase.auth
          .signUp(email: d.email, password: d.password, data: meta);
      if (res.session == null) {
        throw const AuthException(
            'Account created but no session. In Supabase go to Auth -> Providers -> Email and turn off "Confirm email" while developing.');
      }
    }

    final uid = supabase.auth.currentUser!.id;
    final bucket = supabase.storage.from('ic-documents');
    final frontPath = '$uid/front.jpg';
    final backPath = '$uid/back.jpg';
    await bucket.uploadBinary(frontPath, await icFront.readAsBytes(),
        fileOptions: FileOptions(
            upsert: true, contentType: icFront.mimeType ?? 'image/jpeg'));
    await bucket.uploadBinary(backPath, await icBack.readAsBytes(),
        fileOptions: FileOptions(
            upsert: true, contentType: icBack.mimeType ?? 'image/jpeg'));

    await supabase.from('profiles').upsert({
      'id': uid,
      'full_name': d.fullName,
      'username': d.username,
      'email': d.email,
      'phone': d.phone,
      'ic_front_path': frontPath,
      'ic_back_path': backPath,
      'accepted_ic_storage': true,
      'accepted_terms': true,
    });
  }

  // ---------- C3 / C4 vehicles ----------

  static Future<List<Vehicle>> _fetchVehicles(VehicleFilter f) async {
    var q = supabase.from('vehicles').select();
    if (f.type != null) q = q.eq('type', f.type!);
    if (f.availableOnly) q = q.eq('status', 'available');

    final rows = f.sort == VehicleSort.lowestPrice
        ? await q.order('price_per_20min', ascending: true).order('name')
        : await q.order('name');
    return rows.map((m) => Vehicle.fromMap(m)).toList();
  }

  /// Active rental banner on C3.
  static Future<({String vehicle, DateTime end})?> _fetchActiveRental() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final rows = await supabase
        .from('bookings')
        .select('end_time, vehicles(name)')
        .eq('user_id', uid)
        .eq('status', 'active')
        .order('end_time')
        .limit(1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      vehicle: (r['vehicles'] as Map)['name'] as String,
      end: DateTime.parse(r['end_time'] as String).toLocal(),
    );
  }

  // ---------- C5 booking ----------

  static Future<String> _createBooking({
    required Vehicle vehicle,
    required DateTime start,
    required int durationMinutes,
  }) async {
    final blocks = durationMinutes ~/ 20;
    final row = await supabase
        .from('bookings')
        .insert({
          'user_id': supabase.auth.currentUser!.id,
          'vehicle_id': vehicle.id,
          'start_time': start.toUtc().toIso8601String(),
          'end_time': start
              .add(Duration(minutes: durationMinutes))
              .toUtc()
              .toIso8601String(),
          'duration_minutes': durationMinutes,
          'total_price': blocks * vehicle.pricePer20Min,
          'agreed_location_and_late_fee': true,
          'status': 'pending_payment',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }


  // ===================================================================
  // Public API used by the screens.
  // Each call goes to Supabase. With AppConfig.uiPreviewMode = true, a failed
  // call (no connection, tables not matching yet, wrong URL/key) falls back to
  // sample data so every screen still shows.
  // ===================================================================

  static Future<T> _orPreview<T>(Future<T> Function() real, T Function() sample) async {
    try {
      return await real().timeout(const Duration(seconds: 6));
    } catch (e) {
      if (AppConfig.uiPreviewMode) {
        debugPrint('Preview mode: Supabase call failed, using sample data. $e');
        return sample();
      }
      rethrow;
    }
  }

  static Future<void> signIn(String identifier, String password) =>
      _orPreview<void>(() => _signIn(identifier, password), () {});

  static Future<void> createAccount(
    RegistrationData d, {
    required XFile icFront,
    required XFile icBack,
  }) =>
      _orPreview<void>(
          () => _createAccount(d, icFront: icFront, icBack: icBack), () {});

  static Future<List<Vehicle>> fetchVehicles(VehicleFilter f) =>
      _orPreview<List<Vehicle>>(() => _fetchVehicles(f), () => _sampleVehicles(f));

  static Future<({String vehicle, DateTime end})?> fetchActiveRental() =>
      _orPreview<({String vehicle, DateTime end})?>(
        _fetchActiveRental,
        () => (
          vehicle: 'Bicycle B01',
          end: DateTime.now().add(const Duration(minutes: 42)),
        ),
      );

  static Future<String> createBooking({
    required Vehicle vehicle,
    required DateTime start,
    required int durationMinutes,
  }) =>
      _orPreview<String>(
        () => _createBooking(
            vehicle: vehicle, start: start, durationMinutes: durationMinutes),
        () => 'RNT-${DateTime.now().millisecondsSinceEpoch % 100000}',
      );

  // ---------- sample data (preview mode only) ----------

  static const _sample = [
    Vehicle(id: 'B01', name: 'Bicycle B01', type: 'bicycle', pricePer20Min: 3, status: 'available'),
    Vehicle(id: 'B02', name: 'Bicycle B02', type: 'bicycle', pricePer20Min: 3, status: 'available'),
    Vehicle(id: 'S01', name: 'Scooter S01', type: 'scooter', pricePer20Min: 5, status: 'available'),
    Vehicle(id: 'S02', name: 'Scooter S02', type: 'scooter', pricePer20Min: 5, status: 'available'),
    Vehicle(id: 'B03', name: 'Bicycle B03', type: 'bicycle', pricePer20Min: 3, status: 'rented'),
  ];

  static List<Vehicle> _sampleVehicles(VehicleFilter f) {
    final list = _sample.where((v) {
      if (f.type != null && v.type != f.type) return false;
      if (f.availableOnly && !v.isAvailable) return false;
      return true;
    }).toList();
    list.sort((a, b) {
      if (f.sort == VehicleSort.lowestPrice &&
          a.pricePer20Min != b.pricePer20Min) {
        return a.pricePer20Min.compareTo(b.pricePer20Min);
      }
      return a.name.compareTo(b.name);
    });
    return list;
  }

  static String get lateFee => AppConfig.lateFeeLabel;
}