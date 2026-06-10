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
