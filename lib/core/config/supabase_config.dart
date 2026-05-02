class SupabaseConfig {
  const SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xshodrfurizuvsabbbbs.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_RV2Y2PtZbWfmZP4OgKEdvg_4av8jfzz',
  );
  static const redirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: 'io.supabase.sahla://login-callback',
  );
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '531932731672-p22vujs7il43unuock2p5uc6t6h4601n.apps.googleusercontent.com',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  static void ensureConfigured() {
    if (isConfigured) {
      return;
    }

    throw StateError(
      'Supabase is not configured. Pass --dart-define=SUPABASE_URL=... '
      'and --dart-define=SUPABASE_ANON_KEY=... before running the app.',
    );
  }
}
