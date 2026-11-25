import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

/// Customer-side HitPay calls. They go through Supabase Edge Functions, so the
/// HitPay API key is never inside the app.
class HitpayApi {
  static Future<String> createPayment({
    required String rentalId,
    required String method,
  }) async {
    try {
      final res = await supabase.functions.invoke(
        'hitpay-create-payment',
        body: {'rental_id': rentalId, 'method': method},
      );
      final data = res.data;
      if (data is Map && data['url'] is String) return data['url'] as String;
      throw 'The payment page link is missing.';
    } on FunctionException catch (e) {
      throw _message(e);
    }
  }

  /// Opens the HitPay page in the browser (a new tab on web).
  static Future<void> openCheckout(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok) throw 'Could not open the payment page.';
  }

  /// Asks the server whether the payment went through. True once the booking is paid.
  static Future<bool> checkPayment(String rentalId) async {
    final res = await supabase.functions
        .invoke('hitpay-check-payment', body: {'rental_id': rentalId});
    final data = res.data;
    return data is Map && data['paid'] == true;
  }

  static String _message(FunctionException e) {
    final d = e.details;
    if (d is Map && d['error'] != null) return d['error'].toString();
    return e.reasonPhrase ?? 'Payment error (${e.status}).';
  }
}