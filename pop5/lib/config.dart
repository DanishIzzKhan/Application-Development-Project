/// Paste your values from Supabase Dashboard -> Project Settings -> API.
/// Keep the quotes and keep the closing brace at the bottom of this file.
class AppConfig {
  static const supabaseUrl = 'https://olmtsqxuwyjwgknpeabe.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_JvHTnDPvOp0zJXzh_zwMvA_H8qOsF7X';

  /// false = real behaviour: Supabase errors are shown to the user.
  /// true  = if Supabase fails (no connection, wrong key, migration not run yet),
  ///         screens fall back to sample data so you can still see the UI.
  static const uiPreviewMode = false;

  /// Shown on C5 until the owner sets a late rate in shop_settings.
  static const lateFeeLabel = 'RM X';
}