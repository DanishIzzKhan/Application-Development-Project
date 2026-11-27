import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/rental.dart';
import 'api.dart';

/// Aggregated KPI and chart data for O2 Owner Home Dashboard (ADP-130).
class OwnerDashboardData {
  final int availableCount;
  final int onRentalCount;
  final int waitingPaymentCount;
  final int underRepairCount;
  final double monthRevenue;
  final double todayRevenue;
  final List<double> dailyBarHeights;
  final int unreadAlertCount;
  final String latestAlertTitle;
  final int aiMaintenanceCount;

  const OwnerDashboardData({
    required this.availableCount,
    required this.onRentalCount,
    required this.waitingPaymentCount,
    required this.underRepairCount,
    required this.monthRevenue,
    required this.todayRevenue,
    required this.dailyBarHeights,
    required this.unreadAlertCount,
    required this.latestAlertTitle,
    required this.aiMaintenanceCount,
  });
}

/// Owner-side calls to Supabase (rentals, counter payment, start, returned).
/// The database functions check that the signed-in user has role 'owner'.
class OwnerApi {
  static final _hex = RegExp(r'^[0-9a-fA-F]{8,64}$');

  /// Columns O3 / O5 need: the booking, its vehicle and the app customer.
  static const _rentalSelect =
      '*, vehicles(id, type), users(username, full_name, ic_front_path, ic_back_path)';

// ---------- O2 Home Dashboard (ADP-130) ----------

  static Future<OwnerDashboardData> fetchDashboardData() async {
    try {
      final vehicleRows =
          await supabase.from('vehicles').select('id, status, is_active');
      int available = 0;
      int underRepair = 0;
      for (final v in vehicleRows) {
        if (v['is_active'] == false) continue;
        final status = (v['status'] ?? '').toString();
        if (status == 'Available') {
          available++;
        } else if (status == 'Under repair' || status == 'Maintenance') {
          underRepair++;
        }
      }

      final rentalRows = await supabase
          .from('rentals')
          .select('id, status')
          .inFilter(
              'status', ['pending_payment', 'ready', 'checked_in', 'active']);
      int onRental = 0;
      int waitingPayment = 0;
      for (final r in rentalRows) {
        final status = (r['status'] ?? '').toString();
        if (status == 'checked_in' || status == 'active') {
          onRental++;
        } else if (status == 'pending_payment') {
          waitingPayment++;
        }
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final fourteenDaysAgo = todayStart.subtract(const Duration(days: 13));
      final dailyTotals = List<double>.filled(14, 0.0);
      double monthRevenue = 0.0;
      double todayRevenue = 0.0;

      try {
        final paymentRows = await supabase
            .from('payments')
            .select('amount, status, created_at')
            .eq('status', 'completed');

        for (final p in paymentRows) {
          final amount = double.tryParse(p['amount']?.toString() ?? '') ?? 0.0;
          final rawDate = p['created_at']?.toString();
          if (rawDate == null) continue;
          final dt = DateTime.parse(rawDate).toLocal();

          if (dt.year == now.year && dt.month == now.month) {
            monthRevenue += amount;
          }
          if (dt.year == now.year &&
              dt.month == now.month &&
              dt.day == now.day) {
            todayRevenue += amount;
          }

          final dayDate = DateTime(dt.year, dt.month, dt.day);
          final diff = dayDate.difference(fourteenDaysAgo).inDays;
          if (diff >= 0 && diff < 14) {
            dailyTotals[diff] += amount;
          }
        }
      } catch (e) {
        debugPrint('Dashboard payments query fallback: $e');
      }

      final barHeights = _normalizeBarHeights(dailyTotals);

      final alerts = await Api.fetchOwnerAlerts();
      final unreadAlerts =
          alerts.where((a) => a is Map && a['read_at'] == null).toList();
      final latestTitle = unreadAlerts.isNotEmpty
          ? (unreadAlerts.first['title']?.toString() ?? 'New alert')
          : 'All clear';

      int aiCount = 0;
      try {
        final predRows =
            await supabase.from('maintenance_predictions').select().limit(50);
        for (final row in predRows) {
          final status = (row['status'] ?? '').toString().toLowerCase();
          if (status != 'resolved' &&
              status != 'completed' &&
              status != 'dismissed') {
            aiCount++;
          }
        }
      } catch (e) {
        debugPrint('Dashboard AI predictions fallback: $e');
      }

      return OwnerDashboardData(
        availableCount: available,
        onRentalCount: onRental,
        waitingPaymentCount: waitingPayment,
        underRepairCount: underRepair,
        monthRevenue: monthRevenue,
        todayRevenue: todayRevenue,
        dailyBarHeights: barHeights,
        unreadAlertCount: unreadAlerts.length,
        latestAlertTitle: latestTitle,
        aiMaintenanceCount: aiCount,
      );
    } catch (e) {
      if (AppConfig.uiPreviewMode) {
        debugPrint('Preview mode: using sample dashboard data. $e');
        return _sampleDashboardData;
      }
      rethrow;
    }
  }

  static List<double> _normalizeBarHeights(List<double> totals) {
    double maxVal = 0.0;
    for (final v in totals) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal <= 0) {
      return List<double>.filled(14, 14.0);
    }
    return totals.map((v) {
      if (v <= 0) return 14.0;
      final scaled = 14.0 + (v / maxVal) * 54.0;
      return scaled.clamp(14.0, 68.0);
    }).toList();
  }

  static OwnerDashboardData get _sampleDashboardData =>
      const OwnerDashboardData(
        availableCount: 8,
        onRentalCount: 4,
        waitingPaymentCount: 2,
        underRepairCount: 1,
        monthRevenue: 1420,
        todayRevenue: 180,
        dailyBarHeights: [
          24,
          38,
          30,
          52,
          44,
          62,
          36,
          30,
          56,
          42,
          48,
          36,
          42,
          68,
        ],
        unreadAlertCount: 3,
        latestAlertTitle: 'Scooter S02 left Kulai Park',
        aiMaintenanceCount: 2,
      );

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
  static Future _upfrontPayments(List<String> rentalIds) async {
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
  static Future findRental(String value) async {
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
