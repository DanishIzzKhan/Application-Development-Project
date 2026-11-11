import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/registration_data.dart';
import '../models/vehicle.dart';

SupabaseClient get supabase => Supabase.instance.client;

/// Owner-editable rules from `shop_settings` (shown on C5).
class ShopRules {
  final int graceMinutes;
  final double lateRate;
  const ShopRules(this.graceMinutes, this.lateRate);

  String get lateRateLabel =>
      lateRate > 0 ? 'RM ${lateRate.toStringAsFixed(2)}' : AppConfig.lateFeeLabel;
}

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

  /// With AppConfig.uiPreviewMode = true a failed call returns sample data.
  static Future<T> _orPreview<T>(
      Future<T> Function() real, T Function() sample) async {
    try {
      return await real().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (AppConfig.uiPreviewMode) {
        debugPrint('Preview mode: Supabase call failed, using sample data. $e');
        return sample();
      }
      rethrow;
    }
  }

  // ---------- C1 login (Supabase Auth) ----------

  /// [identifier] is a phone number or an email.
  static Future<void> signIn(String identifier, String password) =>
      _orPreview<void>(() async {
        final id = identifier.trim();
        var email = id;
        if (!id.contains('@')) {
          final res = await supabase.rpc('get_email_by_phone',
              params: {'p_phone': normalizePhone(id)});
          if (res == null || (res as String).isEmpty) {
            throw const AuthException('No account found for this phone number.');
          }
          email = res;
        }
        await supabase.auth
            .signInWithPassword(email: email, password: password);
      }, () {});

  // ---------- C2 / C2b create account ----------

  /// Returns 'username', 'phone' or null (no conflict).
  static Future<String?> signupConflict(String username, String phone) =>
      _orPreview<String?>(() async {
        final res = await supabase.rpc('signup_conflict',
            params: {'p_username': username, 'p_phone': phone});
        return res as String?;
      }, () => null);

  /// Supabase Auth sign-up (a database trigger creates the `users` row),
  /// then uploads the IC photos and saves their paths on that row.
  static Future<void> createAccount(
    RegistrationData d, {
    required XFile icFront,
    required XFile icBack,
  }) =>
      _orPreview<void>(() async {
        final res = await supabase.auth.signUp(
          email: d.email,
          password: d.password,
          data: {
            'full_name': d.fullName,
            'username': d.username,
            'phone': d.phone,
          },
        );
        if (res.session == null) {
          throw const AuthException(
              'Account created but not signed in. In Supabase go to Authentication -> Providers -> Email and turn off "Confirm email" while developing.');
        }

        final uid = res.user!.id;
        final bucket = supabase.storage.from('ic-documents');
        final frontPath = '$uid/front.jpg';
        final backPath = '$uid/back.jpg';
        await bucket.uploadBinary(frontPath, await icFront.readAsBytes(),
            fileOptions: FileOptions(
                upsert: true, contentType: icFront.mimeType ?? 'image/jpeg'));
        await bucket.uploadBinary(backPath, await icBack.readAsBytes(),
            fileOptions: FileOptions(
                upsert: true, contentType: icBack.mimeType ?? 'image/jpeg'));

        final updated = await supabase
            .from('users')
            .update({
              'ic_front_path': frontPath,
              'ic_back_path': backPath,
              'accepted_ic_storage': true,
              'accepted_terms': true,
            })
            .eq('id', uid)
            .select('id');
        if (updated.isEmpty) {
          throw Exception(
              'Your profile row was not created. Run the Supabase Auth migration first.');
        }
      }, () {});

  // ---------- C3 / C4 vehicles ----------

  static Future<List<Vehicle>> fetchVehicles(VehicleFilter f) =>
      _orPreview<List<Vehicle>>(() async {
        var q = supabase.from('vehicles').select().eq('is_active', true);
        if (f.type != null) q = q.eq('type', f.type!);
        if (f.availableOnly) q = q.eq('status', 'Available');

        final rows = f.sort == VehicleSort.lowestPrice
            ? await q.order('rate_per_block', ascending: true).order('id')
            : await q.order('id');
        return rows.map((m) => Vehicle.fromMap(m)).toList();
      }, () => _sampleVehicles(f));

  /// Banner on C3: the customer's rental that is checked in / running.
  static Future<({String vehicle, DateTime end})?> fetchActiveRental() =>
      _orPreview<({String vehicle, DateTime end})?>(() async {
        final uid = supabase.auth.currentUser?.id;
        if (uid == null) return null;
        final rows = await supabase
            .from('rentals')
            .select('scheduled_end_time, vehicles(id, type)')
            .eq('customer_id', uid)
            .inFilter('status', ['checked_in', 'active'])
            .order('scheduled_end_time')
            .limit(1);
        if (rows.isEmpty) return null;
        final r = rows.first;
        final v = r['vehicles'] as Map;
        return (
          vehicle: '${v['type']} ${v['id']}',
          end: DateTime.parse(r['scheduled_end_time'] as String).toLocal(),
        );
      }, () => (
            vehicle: 'Bicycle BK-01',
            end: DateTime.now().add(const Duration(minutes: 42)),
          ));

  /// Number on the Notifications tab.
  static Future<int> fetchUnreadCount() => _orPreview<int>(() async {
        final uid = supabase.auth.currentUser?.id;
        if (uid == null) return 0;
        final rows = await supabase
            .from('notifications')
            .select('id')
            .eq('user_id', uid)
            .isFilter('read_at', null);
        return rows.length;
      }, () => 2);

  // ---------- C5 booking ----------

  static Future<ShopRules> fetchShopRules() => _orPreview<ShopRules>(() async {
        final r = await supabase
            .from('shop_settings')
            .select('grace_minutes, late_rate')
            .eq('id', 1)
            .single();
        return ShopRules(
            (r['grace_minutes'] as num).toInt(), (r['late_rate'] as num).toDouble());
      }, () => const ShopRules(5, 0));

  /// Only vehicle, start time and number of 20-minute blocks are sent.
  /// A database trigger sets the price, end time, codes and status.
  static Future<String> createBooking({
    required Vehicle vehicle,
    required DateTime start,
    required int durationMinutes,
  }) =>
      _orPreview<String>(() async {
        final row = await supabase
            .from('rentals')
            .insert({
              'vehicle_id': vehicle.id,
              'scheduled_start_time': start.toUtc().toIso8601String(),
              'blocks_booked': durationMinutes ~/ 20,
            })
            .select('id')
            .single();
        return row['id'] as String;
      }, () => 'RNT-${DateTime.now().millisecondsSinceEpoch % 100000}');

  static String get lateFee => AppConfig.lateFeeLabel;

  // ---------- sample data (preview mode only) ----------

  static const _sample = [
    Vehicle(id: 'BK-01', type: 'Bicycle', pricePer20Min: 3, status: 'Available'),
    Vehicle(id: 'BK-02', type: 'Bicycle', pricePer20Min: 3, status: 'Available'),
    Vehicle(id: 'SC-01', type: 'Scooter', pricePer20Min: 5, status: 'Available'),
    Vehicle(id: 'SC-02', type: 'Scooter', pricePer20Min: 5, status: 'Available'),
    Vehicle(id: 'BK-03', type: 'Bicycle', pricePer20Min: 3, status: 'Rented'),
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
      return a.id.compareTo(b.id);
    });
    return list;
  }
}