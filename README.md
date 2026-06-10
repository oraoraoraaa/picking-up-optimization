# Picking-Up Optimization

A tool for optimizing the process of a driver picking up a passenger.

![screenshot_dashboard_v1](resource/images/screenshot/dashboard_v1.png)

## Problem

When a driver is on the way to pick someone up, the initially selected pickup point is not always the fastest option. Traffic conditions can change at any time across the route, and simply sticking to one fixed point can waste time for both parties.

## Solution

This software continuously analyzes real-time traffic conditions and re-calculates the fastest pickup strategy in all circumstances. It evaluates whether to keep the original pickup point or switch to a better alternative, while considering both driver travel time and passenger transfer time. The passenger can reach recommended points by walking, bicycle, or public transit. By dynamically selecting the best meeting point and route, overall pickup time is reduced for both the driver and the passenger.

## Features

- Continuous fastest-route recalculation for pickup under all traffic conditions
- Alternative pickup point suggestions with passenger mode options: walking, bicycle, and transit
- Joint route estimation for both driver and passenger, with ETA tradeoff comparison

## API

This project uses the [Amap (高德地图) API](https://lbs.amap.com/) for map data, real-time traffic information, and route planning.

---

> Contents below this line is for developers only.

![miku_for_developers](https://github.com/user-attachments/assets/4dbef352-5442-484e-bdbd-c2eea49d2114)

Move to the [contribution guideline](docs/GUIDELINE.md) to check contribution guideline.

This project contains detailed and clear documentations. Reading them using web-ui is recommended as it might not be a pleasant experience to read the tables in raw `.md` files.

## Notice

### V1 Demo

This repository contains a working end-to-end demo:

- Dashboard with live AMap, driver/passenger modes, and POI search ([design](resource/images/design/dashboard_v1.png))
- Route-interception optimization: meeting points are generated along the driver's inbound route, evaluated across walking/bicycle/transit, scored, and compared against staying put
- Result screen with route preview, `FASTEST` summary, meeting-up location, Share, and Open in Maps ([design](resource/images/design/result_v1.png))
- The algorithm's reference implementation lives in the Rust core (`core/`, unit-tested, runnable as a CLI); the app runs a documented on-device Dart mirror of it until the FFI bridge lands

#### Run the App (iOS / Android)

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

Without keys the app still runs with placeholder map layers and deterministic ETA estimates.

#### Run the Rust Core CLI

```bash
cd core
export AMAP_KEY="your_amap_web_service_key"  # optional
cargo run --quiet
```

See [`core/README.md`](core/README.md) and [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) for details.
