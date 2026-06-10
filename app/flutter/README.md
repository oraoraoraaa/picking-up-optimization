# The Flutter App

Mobile-first UI for the pickup optimization demo (iOS / Android with AMap; other platforms fall back to schematic previews).

Whenever you modify the files in this folder, please update the description below.

## What This App Does

- Dashboard (`lib/main.dart`): full-screen AMap with live location, driver/passenger mode selector, POI search (input tips + keyword fallback), map POI tap selection.
- Optimization service (`lib/src/pickup_optimizer.dart`): on-device port of the Rust core engine (`core/src/engine.rs`) — fetches the driver route and candidate ETAs from AMap Web Services, scores and ranks meeting points, and decides versus staying put. Keep its constants in sync with the Rust `EngineConfig`.
- Result page (`lib/src/result_page.dart`): the `resource/images/design/result_v1.png` layout extended with a tappable `SUGGESTIONS` list (v2) — one plan per passenger mode (walk / bicycle / transit) plus stay put, with a `FASTEST` badge on the recommended plan. Selecting a plan redraws the route preview map (driver route + passenger path), refits the camera, and updates the detail card, `MEETING UP LOCATION` card, and the Share / Open in Maps actions.
- Shared key config lives in `lib/src/amap_config.dart`.

## Run

```bash
cd app/flutter
export AMAP_ANDROID_KEY="<your_android_key>"
export AMAP_IOS_KEY="<your_ios_key>"
export AMAP_WEB_KEY="<your_web_service_key>"
flutter run \
  --dart-define=AMAP_ANDROID_KEY=$AMAP_ANDROID_KEY \
  --dart-define=AMAP_IOS_KEY=$AMAP_IOS_KEY \
  --dart-define=AMAP_WEB_KEY=$AMAP_WEB_KEY
```

Without keys the app still runs: the map becomes a placeholder, and the optimizer returns deterministic fallback estimates.

## Test

```bash
flutter test     # result page widget tests + engine-port unit tests
flutter analyze
```
