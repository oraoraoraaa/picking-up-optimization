# Implementation Steps v1

This file contains the technical details of the implementation.

Whenever you add a new feature or make whatever modification, describe them in details and append this documentation.

## Dashboard UI

To display the dashboard:

![dashboard](../resource/images/design/pickup_op_dashboard_v1.png)

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
  