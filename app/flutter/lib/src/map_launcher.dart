import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'app_settings.dart';

/// Deep links are built and launched as raw strings (not `Uri`) because
/// `Uri.parse` lowercases the host and the AMap schemes are documented with
/// case-sensitive segments (`androidamap://viewMap`, `iosamap://viewMap`).

String _fixed(double value) => value.toStringAsFixed(6);

/// Web marker page (also used in share text — works for any recipient).
String webMarkerUrl(LatLng point, String name) {
  return 'https://uri.amap.com/marker?position=${_fixed(point.longitude)},'
      '${_fixed(point.latitude)}&name=${Uri.encodeComponent(name)}'
      '&src=pickup-op';
}

/// Deep link that opens the meeting point in the chosen map application.
///
/// Coordinates are GCJ-02 (AMap datum): AMap consumes them natively and the
/// Baidu link declares `coord_type=gcj02`; Apple Maps also displays GCJ-02
/// within mainland China.
String mapAppMarkerUrl(MapAppChoice app, LatLng point, String name) {
  final encodedName = Uri.encodeComponent(name);
  final lat = _fixed(point.latitude);
  final lon = _fixed(point.longitude);

  switch (app) {
    case MapAppChoice.amap:
      final scheme = defaultTargetPlatform == TargetPlatform.android
          ? 'androidamap'
          : 'iosamap';
      return '$scheme://viewMap?sourceApplication=pickup-op'
          '&poiname=$encodedName&lat=$lat&lon=$lon&dev=0';
    case MapAppChoice.appleMaps:
      return 'https://maps.apple.com/?q=$encodedName&ll=$lat,$lon';
    case MapAppChoice.baiduMaps:
      return 'baidumap://map/marker?location=$lat,$lon&title=$encodedName'
          '&content=$encodedName&src=pickup-op&coord_type=gcj02';
    case MapAppChoice.browser:
      return webMarkerUrl(point, name);
  }
}

/// Map app choices that make sense on the current platform.
List<MapAppChoice> availableMapApps() {
  final isApple =
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return <MapAppChoice>[
    MapAppChoice.amap,
    if (isApple) MapAppChoice.appleMaps,
    MapAppChoice.baiduMaps,
    MapAppChoice.browser,
  ];
}

/// Open the meeting point in the preferred map app, falling back to the web
/// marker page when the app is not installed / the scheme cannot be handled.
/// Returns false when even the fallback failed.
Future<bool> openInMapApp(MapAppChoice app, LatLng point, String name) async {
  try {
    if (await launchUrlString(
      mapAppMarkerUrl(app, point, name),
      mode: LaunchMode.externalApplication,
    )) {
      return true;
    }
  } catch (_) {
    // Unhandled scheme (app not installed) — fall through to the web page.
  }

  if (app == MapAppChoice.browser) return false;
  try {
    return await launchUrlString(
      webMarkerUrl(point, name),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
