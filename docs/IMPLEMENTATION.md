# Implementation Steps v1

This file contains the technical details of the implementation.

Whenever you add a new feature or make whatever modification, describe them in details and append this documentation.

## Dashboard UI

To display the dashboard:

![dashboard](../resource/images/design/dashboard_v1.png)

We need:

- An interactive map in full screen as the bottom layer, showing the user's current location

  - Use `amap_map` package provided as a dart package. See `https://pub.dev/packages/amap_map`

- A small floating window on the upper right of the screen for current mode

  - When untouched, the window display the current mode, having two values: "Driver Mode" or "Passenger Mode"
  - When clicked, the window expand as a selection window, allowing the user to select the two modes

- A floating window on the bottom of the screen taking user input

  - In driver mode, the upper search bar would have the prompt: "Where is your passenger?"
  - In passenger mode, the upper search bar would have the prompt: "Where is your driver?"
  - The search function can be implemented using the `amap_map` package if available, or using the amap search API. See [`docs/amap/search_poi.md`](amap/search_poi.md)

### Implementation Update (2026-03-26)

Implemented a new dashboard-first UI in Flutter and set it as the application home screen.

File modified:

- `app/flutter/lib/main.dart`

Completed items:

- Replaced the previous vertical slice page with `DashboardPage` so the app directly opens the dashboard.
- Added a full-screen map layer placeholder using a `Stack` background:
  - A dark map-like gradient background.
  - A lightweight `CustomPainter` grid/route texture for visual structure.
  - A centered current-location marker icon.
- Added top-right floating mode selector:
  - Collapsed state shows either `Driver Mode` or `Passenger Mode`.
  - Tap expands into `Mode Selection` with two options:
    - `I'm the driver`
    - `I'm the passenger`
  - Current selection is shown with a check icon.
  - Selecting an option updates mode and collapses the selector.
- Added bottom floating input panel:
  - Panel title: `Pick up Optimization`.
  - Mode-aware primary prompt:
    - Driver mode: `Where's your passenger?`
    - Passenger mode: `Where's your driver?`
  - Two rounded search-bar UI placeholders with search icon and hint text.
  - `Start Route Optimizing` primary CTA button.

Notes:

- The search behavior is intentionally left as UI-only placeholder for now.
- The map is currently a visual placeholder layer to ensure the dashboard is displayable immediately.
- Next step is to replace the placeholder map with real `amap_map` integration and wire GPS/search interactions.

### Implementation Update (2026-03-26, AMap Integration)

Integrated `amap_map` into the dashboard so the app can render a real interactive map as the background and display the user's live location.

Files modified:

- `app/flutter/pubspec.yaml`
- `app/flutter/lib/main.dart`
- `app/flutter/android/app/src/main/AndroidManifest.xml`
- `app/flutter/ios/Runner/Info.plist`
- `app/flutter/ios/Podfile`

Completed items:

- Added dependencies:
  - `amap_map`
  - `x_amap_base`
  - `permission_handler`
- Replaced the custom-painted placeholder map layer in `DashboardPage` with `AMapWidget`.
- Added AMap SDK initialization and privacy agreement update:
  - `AMapInitializer.init(context, apiKey: ...)`
  - `AMapInitializer.updatePrivacyAgree(...)`
- Added map my-location visualization using `MyLocationStyleOptions(true, ...)`.
- Added `onLocationChanged` behavior to move camera to the first detected user location.
- Added Android permissions and compatibility flag for AMap runtime:
  - `ACCESS_COARSE_LOCATION`
  - `ACCESS_FINE_LOCATION`
  - `INTERNET`
  - `ACCESS_NETWORK_STATE`
  - `android:allowNativeHeapPointerTagging="false"`
- Added iOS location usage descriptions and ATS allowance in `Info.plist`.
- Added iOS `permission_handler` location compile flag in `Podfile`:
  - `PERMISSION_LOCATION=1`

API key configuration:

- AMap keys are currently injected through build-time defines:
  - `AMAP_ANDROID_KEY`
  - `AMAP_IOS_KEY`
- Example run pattern:

```bash
export AMAP_ANDROID_KEY="<your_android_key>"
export AMAP_IOS_KEY="<your_ios_key>"
flutter run \
  --dart-define=AMAP_ANDROID_KEY=$AMAP_ANDROID_KEY \
  --dart-define=AMAP_IOS_KEY=$AMAP_IOS_KEY
```

Notes:

- If keys are not provided (or app runs on unsupported platforms like web/desktop), dashboard falls back to a non-interactive gradient background with a setup hint card.
- Current location permission is requested via `permission_handler` (`locationWhenInUse`).

### Implementation Update (2026-03-26, Location-first Camera Focus)

Adjusted dashboard map behavior so camera focus procedure is strictly location-first:

- The map now stays behind a loading layer (`Fetching current location...`) until the first valid location callback is received.
- Once the first valid location is fetched, camera focus moves to user location via `CameraUpdate.newLatLngZoom(...)`.
- Only after that first focus update does the loading layer disappear.

Result:

- The user no longer sees the initial Beijing camera position before recentering.

### Implementation Update (2026-03-26, POI Search Suggestions and Selection)

Implemented interactive place search on both dashboard search bars with AMap suggestion APIs and map selection behavior.

Files modified:

- `app/flutter/lib/main.dart`
- `app/flutter/pubspec.yaml`

Completed items:

- Added `http` dependency for calling AMap Web Service APIs.
- Added two real input fields for the existing dashboard search bars:
  - Pickup target search (`Where's your passenger?` / `Where's your driver?`)
  - Alternate start point search (`Starting from a different location?`)
- Added debounced live search while typing:
  - Primary source: AMap Input Tips API (`/v3/assistant/inputtips`, `datatype=poi`)
  - Fallback source: AMap POI keyword search API (`/v3/place/text`)
- Added suggestion dropdown UI with consistent glass/teal visual style:
  - Loading state
  - Empty state
  - Error state
  - Tap-to-select list items showing name + address/district
- Added selection behavior:
  - Filling the tapped location into the corresponding input field
  - Closing suggestion panel
  - Moving map camera to selected location
  - Showing selected locations as markers on the AMap layer
- Added nearby-priority suggestion behavior by sending current user location to Input Tips when available.

API key behavior:

- Search requests use a dedicated build-time define first:
  - `AMAP_WEB_KEY`
- Fallback behavior when `AMAP_WEB_KEY` is missing:
  - Android uses `AMAP_ANDROID_KEY`
  - iOS uses `AMAP_IOS_KEY`

Recommended run pattern:

```bash
export AMAP_ANDROID_KEY="<your_android_key>"
export AMAP_IOS_KEY="<your_ios_key>"
export AMAP_WEB_KEY="<your_web_service_key>"
flutter run \
  --dart-define=AMAP_ANDROID_KEY=$AMAP_ANDROID_KEY \
  --dart-define=AMAP_IOS_KEY=$AMAP_IOS_KEY \
  --dart-define=AMAP_WEB_KEY=$AMAP_WEB_KEY
```

Notes:

- `amap_map` itself does not provide built-in POI autocomplete/search methods in `AMapController`, so search suggestions are implemented through AMap Web Service APIs.
- If no valid search key is configured, the suggestion panel displays a setup hint.

### Implementation Update (2026-03-26, Keyboard Dismissal & Interactive Map POI Selection)

Enhanced UX with keyboard dismissal and interactive map-based location selection.

Files modified:

- `app/flutter/lib/main.dart`

Completed items:

**Keyboard Dismissal:**
- Wrapped the main dashboard `Stack` in a `GestureDetector` with `onTap` handler.
- Calls `FocusScope.of(context).unfocus()` to dismiss keyboard when user taps outside search inputs.
- Result: Keyboard closes automatically when clicking on map or other UI elements.

**Interactive Map POI Selection:**
- Enabled POI tap detection on `AMapWidget`:
  - Set `touchPoiEnabled: true` to allow POI tapping.
  - Registered `onPoiTouched` callback to capture tapped locations.
- Implemented map POI tap handler (`_onMapPoiTapped`):
  - Dismisses keyboard via `FocusScope.unfocus()`.
  - Triggers bottom sheet modal.
- Created context-aware bottom sheet (`_showPoiSelectionBottomSheet`):
  - Displays POI name as header.
  - Shows two mode-specific action buttons:
    - **Driver Mode**: "My passenger is here" (set as pickup) + "I'll go from here" (set as start).
    - **Passenger Mode**: "My driver is here" (set as pickup) + "I'm here" (set as start).
  - Buttons close bottom sheet after selection and trigger marker refresh.
- Added POI selection handlers (`_setPickupFromPoi`, `_setStartFromPoi`):
  - Creates `_PoiSuggestion` object from tap coordinates (using POI name, id, latLng).
  - Updates corresponding controller text (pickup/start input field).
  - Refreshes map markers to show selected location.
  - Clears active search field state.

Technical Notes:

- `AMapPoi` class from `amap_map` package contains only: `name`, `id`, `latLng` properties.
- No address/district information is available from map POI taps, so these fields are set to empty strings in the selection model.
- If address information is needed from map taps, a reverse geocoding API call would be required (separate implementation).
- Bottom sheet only displays POI name without subtitle (address unavailable).

### Implementation Results (2026-03-26)

![screenshot_dashboard_v1](../resource/images/screenshot/dashboard_v1.png)

### Implementation Update (2026-03-27, Smooth Interaction Animations)

Added smooth transitions across dashboard interactive widgets so state changes feel continuous instead of abrupt.

Files modified:

- `app/flutter/lib/main.dart`

Completed items:

- Added shared animation timing constants for consistent motion across widgets.
- Enhanced top-right mode selector animation:
  - Wrapped selector with `AnimatedSize` for smooth size interpolation.
  - Added `AnimatedSwitcher` + fade/scale transition between collapsed and expanded states.
  - Preserved selection behavior while making expansion/collapse feel fluid.
- Enhanced mode option selection animation:
  - Replaced static option container with `AnimatedContainer` so selected/unselected background and border transition smoothly.
  - Added `AnimatedSwitcher` for check icon appearance/disappearance.
- Enhanced bottom prompt transition:
  - Wrapped mode-dependent prompt text with `AnimatedSwitcher` using fade + slide transition when switching Driver/Passenger mode.
- Enhanced search bar interaction animation:
  - Replaced static search field shell with `AnimatedContainer`.
  - Added active-state transitions (subtle glow, stronger border, slightly stronger fill) when field is focused/active.
  - Added `AnimatedSwitcher` for trailing search action (loading spinner / clear button / empty placeholder).
- Enhanced map loading overlay transition:
  - Replaced hard show/hide with `AnimatedSwitcher` so the initial location-loading overlay fades out smoothly after first location lock.

Notes:

- Existing interaction logic (mode changes, search behavior, marker updates, POI bottom sheet actions) remains unchanged.
- This update is purely UX motion polish, designed to improve perceived responsiveness without changing business behavior.

## Rust Core Optimization Engine

### Implementation Update (2026-06-10, Route-Interception Engine v1)

Replaced the hardcoded vertical-slice binary in `core/` with a structured library + CLI implementing the first real optimization algorithm.

Files modified/created:

- `core/src/domain.rs` (new): shared DTOs — `GeoPoint`, `NamedPoint`, `MobilityMode`, `RoutePoint`, `Candidate`, `EvaluatedOption`, `Recommendation`, `RecommendationSet`, `Scenario`.
- `core/src/engine.rs` (new): the pure algorithm (no I/O, fully unit-tested).
- `core/src/amap.rs` (new): blocking AMap Web Service clients + deterministic fallbacks.
- `core/src/lib.rs` (new): `run_analysis` orchestrator.
- `core/src/main.rs` (rewritten): thin CLI around the library.

The algorithm (route interception):

1. Fetch the driver's driving route to the passenger (AMap `direction/driving`, `extensions=all`), building per-vertex cumulative travel time by distributing each step's duration proportionally over its polyline segment lengths.
2. Generate meeting-point candidates on that route: vertices within the passenger's reach (walk ≤ 1.2 km, bicycle ≤ 3.5 km, transit 2–8 km straight-line), requiring a non-trivial passenger move (≥ 120 m) and a minimum driver saving (≥ 60 s). Candidates are spaced ≥ 250 m apart and evenly downsampled to at most 4 to bound API fan-out.
3. Evaluate each candidate × reachable mode with passenger ETAs from AMap walking/bicycling/transit APIs (deterministic speed-based fallbacks when unavailable).
4. Score with a weighted objective:
   `score = max(driver_eta, passenger_eta) + 0.15 * passenger_eta + mode_penalty` (bicycle +1.0 min, transit +2.5 min).
5. Rank ascending with tie-breakers (lower passenger effort, then lower driver ETA) and recommend the winner only if it beats the stay-put baseline by ≥ 1.5 min; otherwise recommend staying put.

Output (`RecommendationSet` JSON) includes the best recommendation, up to 2 alternatives, the driver route polyline truncated at the meeting point, and the passenger path polyline (walking path from AMap when applicable) so the UI can render both routes.

CLI usage:

```bash
cd core
cargo run --quiet                  # built-in Shanghai demo scenario
cargo run --quiet -- scenario.json # scenario from file
echo '{"driver":{"lon":121.5086,"lat":31.2454},"passenger":{"lon":121.4737,"lat":31.2304},"city":"上海"}' | cargo run --quiet -- -
```

`AMAP_KEY` enables live routing; without it the run degrades to deterministic estimates (`data_source: "fallback"`).

Testing: `cargo test` covers candidate generation (reach/spacing/cap/driver-saving invariants), mode gating, scoring monotonicity, ranking tie-breakers, and the stay-put decision rule (10 tests).

Note on app integration: the Rust core is the reference engine. The Flutter app currently runs an on-device Dart mirror of the same engine (see next section) because the `flutter_rust_bridge` FFI bridge is not wired yet; wiring it is the next planned step, and the shared formulas/constants are documented on both sides to stay in sync.

## Result UI and Optimization Flow

### Implementation Update (2026-06-10, Result Page per result_v1.png)

Implemented the result screen design (`resource/images/design/result_v1.png`) and wired the dashboard's `Start Route Optimizing` button to a full on-device optimization flow.

Files modified/created:

- `app/flutter/lib/src/amap_config.dart` (new): shared build-time key configuration (extracted from `main.dart`).
- `app/flutter/lib/src/pickup_optimizer.dart` (new): on-device optimization service — a documented Dart port of `core/src/engine.rs` (same candidate generation, weights, and decision rule) calling AMap driving/walking/bicycling/transit/regeo Web Service APIs, with the same deterministic fallbacks.
- `app/flutter/lib/src/result_page.dart` (new): the result screen.
- `app/flutter/lib/main.dart`: wired `_startOptimizing` to the CTA button; key config now delegates to `amap_config.dart`.
- `app/flutter/pubspec.yaml`: added `url_launcher`.
- `app/flutter/macos/Runner/Release.entitlements`: added `com.apple.security.network.client` so sandboxed release builds can call AMap.
- `app/flutter/test/widget_test.dart`: replaced the stale vertical-slice test with result-page widget tests and engine-port unit tests.

Flow:

- Driver mode: pickup field = passenger location, start field (or live GPS) = driver start.
- Passenger mode: pickup field = driver location, start field (or live GPS) = passenger start.
- Missing inputs surface as floating snackbar hints; otherwise the app pushes `ResultPage`, which runs `PickupOptimizer.optimize` with loading/error/retry states.

Result page contents (per design):

- Route preview map card: on iOS/Android with keys, a live `AMapWidget` with traffic, the driver route polyline (blue), the passenger path polyline (dashed green), markers for driver/passenger/meeting point, and camera fitted to the route bounds; elsewhere, a `CustomPainter` schematic that projects the real polylines into the card. Floating chips show `Drive X min` and `<Mode> Y min · Suggested`.
- Green `FASTEST` card: passenger instruction (`Walk 5 mins to <place>`) and driver benefit (`Save 7 mins driving time`), with stay-put variants.
- Pink `MEETING UP LOCATION:` card: meeting point name + address resolved via AMap reverse geocoding (nearby POI preferred, formatted address fallback, coordinates as last resort).
- `Share` button: copies a plan summary + AMap link to the clipboard.
- `Open in Maps` button: opens `https://uri.amap.com/marker?...` via `url_launcher` (AMap app or browser).
- Header shows a data-source badge: `Live traffic` / `Live + estimates` / `Estimates only`.

Verification: `flutter analyze` clean, `flutter test` 6/6 passing, `flutter build macos --debug` succeeds, `cargo test` 10/10 passing.

## V2: Multi-Suggestion Results (Walk / Bicycle / Transit / Stay Put)

### Implementation Update (2026-06-10, Per-Mode Suggestions in the Core)

Extended the Rust core so a single analysis returns one displayable plan per passenger mode instead of only the overall best.

Files modified:

- `core/src/engine.rs`: added `best_per_mode(ranked)` — reduces the ranked option list to the best-scored option per mode while preserving rank order (the first occurrence of each mode is that mode's winner since the input is sorted). Two new unit tests (12 total).
- `core/src/amap.rs`: added `fetch_bicycling_path` (duration + step polylines from the v4 bicycling API); bicycle durations now reuse it.
- `core/src/domain.rs`: replaced the v1 `best`/`alternatives` output with the v2 schema:
  - `Suggestion` — one per-mode plan carrying `mode`, `recommended`, meeting point, driver/passenger/completion ETAs, `driver_saved_min`, `score`, rationale, and its own `driver_route_polyline` (truncated at that plan's meeting point) + `passenger_path_polyline`.
  - `StayPutSuggestion` — the baseline plan with the full driver route polyline.
  - `RecommendationSet` — `{ stay_put, suggestions: [...] }`; exactly one entry across both carries `recommended: true`.
- `core/src/lib.rs`: orchestrator builds per-mode winners via `best_per_mode`, fetches per-suggestion passenger paths (walking and bicycling via real path APIs, transit as a straight line), and sets the recommended flag from the existing `decide` rule (per-mode winners preserve rank order, so when a switch wins it is exactly the first winner).

### Implementation Update (2026-06-10, Multi-Suggestion Result UI)

The result page now presents all options — passenger walking, bicycle, transit, and stay put — as a tappable list.

Files modified:

- `app/flutter/lib/src/pickup_optimizer.dart`:
  - Added `bestPerMode` (mirrors `engine::best_per_mode`).
  - `PickupSuggestion` replaces the single recommendation model; the stay-put plan is folded in as a suggestion with `mode == null`. Each suggestion carries its own polylines and a reverse-geocoded name/address (the regeo helper now returns both a POI name and a formatted address).
  - `OptimizationResult.suggestions` lists the recommended entry first, the rest ascending by score; stay-put is always present.
  - Bicycle suggestions now use the real v4 bicycling path polyline (shared `_fetchPathPolyline` helper); transit remains a straight dashed line.
- `app/flutter/lib/src/result_page.dart`:
  - New `SUGGESTIONS` section between the map and detail cards: one tile per plan with mode icon, passenger time (`Walk 5 min`), meeting point name, total completion time, driver saving (`driver −7 min`), and a green `FASTEST` badge on the recommended plan.
  - Tapping a tile selects it: the map redraws that plan's polylines/markers and refits the camera (`AMapController` retained for `newLatLngBounds` moves), and the detail/meeting/action cards switch to the selection.
  - Detail card title reflects the selection: `FASTEST` (green gradient) for the recommended plan, `ALTERNATIVE` / `STAY PUT` (slate gradient) otherwise.
  - Share / Open in Maps act on the currently selected suggestion.
- `app/flutter/test/widget_test.dart`: updated for the v2 model — verifies one tile per mode plus stay-put, the FASTEST badge, tap-to-switch behavior across detail cards, the stay-put-wins layout, and the `bestPerMode` port.

Verification: `cargo test` 12/12, clippy clean; `flutter analyze` clean, `flutter test` 8/8, `flutter build macos --debug` succeeds. CLI smoke run (fallback mode) returns bicycle (recommended) + walking + transit suggestions with per-suggestion polylines.

### Implementation Update (2026-06-10, Edge-to-Edge Dashboard, Result Map Gestures, UX/Perf Polish)

Files modified:

- `app/flutter/lib/main.dart`
- `app/flutter/lib/src/result_page.dart`

**Dashboard letterboxing fix (black bars):**

- Removed the full-screen `SafeArea` that was insetting the whole dashboard body and exposing the dark scaffold background above/below the map on notched iPhones.
- The map now renders edge-to-edge; floating widgets (mode selector, map action buttons, bottom panel) position themselves with `MediaQuery.paddingOf` safe insets instead.
- Added a subtle top gradient scrim under the status bar for legibility, and an `AnnotatedRegion<SystemUiOverlayStyle>` that switches status bar icons to dark over the light map (light while the loading overlay/fallback background shows).

**Dashboard new functions + beautification:**

- Added two floating circular map action buttons (top-left, mirroring the mode selector):
  - Traffic toggle: switches the AMap real-time traffic layer on/off (`trafficEnabled` is now state).
  - Recenter: animates the camera back to the user's current location (hint snackbar when location isn't available yet).
- Buttons use solid translucent fills (no extra `BackdropFilter` cost) with an active-state teal tint.

**Result page map gesture fix:**

- The route preview `AMapWidget` sits inside a `SingleChildScrollView`, which was claiming vertical drags before the platform view saw them (taps/double-taps worked, panning didn't).
- Fixed by passing `gestureRecognizers: {Factory(EagerGestureRecognizer.new)}` so the map claims drags eagerly; panning now moves the map and page scrolling happens outside the map card.

**Animation smoothness:**

- Mode selector now expands out of its top-right corner: `AnimatedSize`/`AnimatedSwitcher` share a top-right alignment (custom `layoutBuilder` + anchored `ScaleTransition`) instead of growing from the center.
- Bottom panel height changes (suggestion dropdown appearing/disappearing) animate via an `AnimatedSize` wrapper instead of snapping.
- Result page detail + meeting-location cards cross-fade/slide via a keyed `AnimatedSwitcher` when a different suggestion is selected.
- Standard durations tightened to 240ms/160ms with `easeOutQuart`/`easeOutCubic` curves.

**Lightweight optimizations:**

- `AMapInitializer.init`/`updatePrivacyAgree` now run once (guarded) instead of on every dashboard rebuild.
- Glass-card `BackdropFilter` blur sigma reduced 16 -> 10 (visually equivalent, cheaper to composite over the map).
- `RepaintBoundary` around the schematic route preview painter so page scrolling doesn't re-rasterize it.

Verification: `dart format` applied, `flutter analyze` clean, `flutter test` 8/8, `flutter build macos --debug` succeeds.

### Implementation Update (2026-06-10, Language Switching, Default Map App, Settings Panel)

Files created:

- `app/flutter/lib/src/app_settings.dart`: `AppSettings` (`ChangeNotifier`) holding the display language (`en` / `zhHans` / `ja`) and the default map app (`amap` / `appleMaps` / `baiduMaps` / `browser`), persisted with `shared_preferences`; exposed app-wide through `AppSettingsScope` (`InheritedNotifier`). First launch follows the device language when supported. An `AppSettings.inMemory` constructor serves tests.
- `app/flutter/lib/src/l10n.dart`: lightweight string table `S` — every UI string resolves through `_t(en, zh, ja)`; looked up via `S.of(context)` so dependent widgets rebuild on language change. Falls back to English when no scope is present (bare widget tests).
- `app/flutter/lib/src/map_launcher.dart`: builds map deep links and launches them. Links are raw strings via `launchUrlString` (not `Uri`) because `Uri.parse` lowercases hosts while AMap documents case-sensitive segments (`androidamap://viewMap`); coordinates use fixed 6-decimal formatting. AMap (`iosamap://` / `androidamap://`), Apple Maps (`maps.apple.com` universal link, Apple platforms only), Baidu (`baidumap://...&coord_type=gcj02`), or browser. Unhandled schemes (app not installed) fall back to the AMap web marker page.

Files modified:

- `app/flutter/lib/main.dart`:
  - `main()` is async: loads persisted settings before `runApp`; the app is wrapped in `AppSettingsScope`.
  - New hamburger (three-line) button next to the top-right mode selector. Tapping it expands the corner cluster into a glass settings panel with two sections: **Language** (English / 简体中文 / 日本語) and **Default map app** (platform-filtered choices), each with check-marked options applied and persisted immediately.
  - All dashboard strings localized; search error state refactored from a stored string to a kind enum so messages follow language switches.
- `app/flutter/lib/src/result_page.dart`: fully localized (header, badges, loading/error, suggestion tiles, detail cards, share text); `Open in Maps` now launches the configured map application instead of always opening the browser. Share text keeps the web marker link so recipients don't need any specific app.
- `app/flutter/lib/src/pickup_optimizer.dart`: reverse-geocode fallback name is now empty and substituted with a localized label at display time.
- `app/flutter/ios/Runner/Info.plist`: added `LSApplicationQueriesSchemes` (`iosamap`, `baidumap`).
- `app/flutter/android/app/src/main/AndroidManifest.xml`: added `<queries>` intents for the `androidamap`, `baidumap`, and `https` schemes (Android 11+ package visibility).
- `app/flutter/pubspec.yaml`: added `shared_preferences`.
- `app/flutter/test/widget_test.dart`: added localization tests (Chinese and Japanese result pages via `AppSettingsScope` + `AppSettings.inMemory`) and map-link unit tests (AMap scheme case preservation, Baidu GCJ-02 declaration, browser fallback URL).

Verification: `flutter analyze` clean, `flutter test` 13/13, `flutter build macos --debug` succeeds (new pod resolved).
