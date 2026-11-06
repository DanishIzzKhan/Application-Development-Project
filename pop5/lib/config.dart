/// Paste your values from Supabase Dashboard -> Project Settings -> API.
class AppConfig {
  static const supabaseUrl = 'https://olmtsqxuwyjwgknpeabe.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_JvHTnDPvOp0zJXzh_zwMvA_H8qOsF7X';

  /// The wireframe has an SMS verification code on C2.
  /// SMS needs a provider (e.g. Twilio) enabled in Supabase -> Auth -> Providers -> Phone.
  /// Keep this false while developing; set true once SMS is configured.
  static const requireSmsVerification = false;

   /// true  = the Supabase connection stays in the code, but if it is not reachable
  ///         or the tables don't match yet, the screens still show using sample data
  ///         (login / create account / booking just continue to the next screen).
  /// false = real behaviour: errors are shown to the user.
  static const uiPreviewMode = true;

  /// Wireframe shows "[RM X]" for the late charge. Replace when the fee is decided.
  static const lateFeeLabel = 'RM X';

  /// Placeholder until the notifications table exists (C13).
  static const notificationBadge = 2;
}