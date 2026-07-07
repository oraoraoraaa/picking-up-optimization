import 'package:flutter/foundation.dart';
import 'package:x_amap_base/x_amap_base.dart';

/// Build-time AMap key configuration shared by the dashboard and result page.
///
/// Keys are injected with --dart-define:
///   AMAP_ANDROID_KEY / AMAP_IOS_KEY  - native map SDK keys
///   AMAP_WEB_KEY                     - Web Service key (search, routing)
const AMapApiKey amapApiKeys = AMapApiKey(
  androidKey: String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: ''),
  iosKey: String.fromEnvironment('AMAP_IOS_KEY', defaultValue: ''),
);

const AMapPrivacyStatement amapPrivacyStatement = AMapPrivacyStatement(
  hasContains: true,
  hasShow: true,
  hasAgree: true,
);

const String amapWebKey = String.fromEnvironment(
  'AMAP_WEB_KEY',
  defaultValue: '',
);

/// Base URL of the pickup-optimization backend (the Rust `server/` crate),
/// e.g. `https://api.example.com`. Injected with --dart-define:
///   PICKUP_API_BASE   backend base URL (no trailing slash)
///   PICKUP_API_TOKEN  shared secret sent as the `X-App-Token` header
///
/// When set, the app runs optimization through the backend (which holds the
/// Web Service key) and only falls back to the on-device engine if the backend
/// is unreachable. When empty, the app computes everything on-device using
/// [effectiveAmapWebKey].
const String pickupApiBaseUrl = String.fromEnvironment(
  'PICKUP_API_BASE',
  defaultValue: '',
);

const String pickupApiToken = String.fromEnvironment(
  'PICKUP_API_TOKEN',
  defaultValue: '',
);

bool get hasPickupBackend => pickupApiBaseUrl.trim().isNotEmpty;

bool get supportsAmapPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

bool get hasConfiguredMapKey {
  final android = (amapApiKeys.androidKey ?? '').trim();
  final ios = (amapApiKeys.iosKey ?? '').trim();
  return android.isNotEmpty || ios.isNotEmpty;
}

/// Web Service key used for REST calls, falling back to the platform map key.
String get effectiveAmapWebKey {
  final web = amapWebKey.trim();
  if (web.isNotEmpty) return web;
  if (defaultTargetPlatform == TargetPlatform.android) {
    return (amapApiKeys.androidKey ?? '').trim();
  }
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return (amapApiKeys.iosKey ?? '').trim();
  }
  return '';
}
