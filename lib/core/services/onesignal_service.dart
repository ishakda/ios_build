import 'package:untitled1/core/config/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:developer' as developer;

class OneSignalService {
  static String get _appId => SupabaseConfig.oneSignalAppId;

  static bool get isConfigured =>
      _appId.isNotEmpty && _appId != 'YOUR_ONESIGNAL_APP_ID';

  static Future<void> initialize() async {
    try {
      if (!isConfigured) {
        developer.log('OneSignal skipped: ONESIGNAL_APP_ID is not configured.');
        return;
      }

      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      } else {
        OneSignal.Debug.setLogLevel(OSLogLevel.none);
      }

      OneSignal.initialize(_appId);

      // The promptForPushNotificationsWithUserResponse function will show the iOS or Android 13+ push notification prompt.
      // We recommend removing the following code and instead using an In-App Message to prompt for notification permission
      OneSignal.Notifications.requestPermission(true);

      developer.log("OneSignal initialized successfully");
    } catch (e) {
      developer.log("Error initializing OneSignal: $e");
    }
  }

  static void setExternalUserId(String userId) {
    if (!isConfigured) {
      return;
    }
    OneSignal.login(userId);
  }

  static void logout() {
    if (!isConfigured) {
      return;
    }
    OneSignal.logout();
  }
}
