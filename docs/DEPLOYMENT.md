# Deployment: Backend Gateway + Mobile App

This guide explains how to run the app on a real phone using the **thin backend gateway** architecture: the phone renders the map and UI, and a small server holds the AMap Web Service key and runs the Rust optimization engine.

## Why this shape

AMap gives you two kinds of keys, and they must be handled differently:

| Key                          | Where it lives           | Why                                                                 |
| ---------------------------- | ------------------------ | ------------------------------------------------------------------- |
| Map **SDK** key (iOS/Android)| Embedded in the app      | The native map widget needs it on-device; AMap binds it to your bundle ID, so extraction risk is low. |
| Web **Service** key          | **Server only**          | Drives routing/geocoding; has QPS quota + billing. Shipping it lets anyone drain your quota. |

So the app ships only its Map SDK key; all keyed routing/geocoding happens behind the server. The server also does reverse geocoding, so responses are **display-ready** (meeting-point names + addresses) and the phone needs no Web Service key at all.

```text
┌─────────────┐   POST /analyze {driver,passenger}   ┌────────────────────┐
│ Flutter app │ ───────────────────────────────────▶ │ pickup-op-server   │
│ (map SDK    │                                       │  • holds AMAP_KEY  │
│  key only)  │ ◀─────────────────────────────────── │  • runs core engine│
└─────────────┘   RecommendationSet JSON (cached)     │  • AMap Web APIs   │
       │                                              └────────────────────┘
       └─ backend unreachable? → on-device fallback (estimates only)
```

If `PICKUP_API_BASE` is unset the app falls back to computing everything on-device (the previous behavior), which then *does* require a Web Service key on the phone. For a shipped product, prefer the backend.

---

## Part 1 — What goes in the server

The server is the [`server/`](../server) crate. It exposes:

- `GET /health` — liveness probe.
- `POST /analyze` — takes `{driver, passenger, city?}`, returns the `RecommendationSet` the app renders.

It provides, in one place:

- **Key custody** — `AMAP_KEY` lives only in the server's environment.
- **Auth gate** — `APP_TOKEN`; requests must send a matching `X-App-Token` header or get `401`. This is the main defense against strangers draining the AMap quota.
- **Caching** — identical requests (coordinates rounded to ~11 m + city) reuse one response for `CACHE_TTL_SECS` (default 60 s, short because it reflects live traffic). Response header `X-Cache: HIT|MISS`.
- **CORS** — permissive, so a Flutter *web* build can call it too.
- **Graceful shutdown** and structured logs.

See [`server/README.md`](../server/README.md) for the request/response schema and [`server/.env.example`](../server/.env.example) for all env vars.

### 1.1 Deploy in Server

Anything that runs a container or a static Linux binary works (Fly.io, Render, Railway, Google Cloud Run, AWS App Runner, a plain VPS…).

Container path:

```bash
# Build from the repo ROOT (the crate depends on ../core):
docker build -t pickup-op-server .

docker run --rm -p 8080:8080 \
  -e AMAP_KEY=your_web_service_key \
  -e APP_TOKEN=$(openssl rand -hex 24) \
  -e CACHE_TTL_SECS=60 \
  pickup-op-server
```

**Put HTTPS in front of it.** Phones should only talk to the backend over TLS. Either deploy behind a platform that terminates TLS for you (Cloud Run, Fly, Render all do), or run a reverse proxy (Caddy/nginx/Traefik) with a real certificate. Keep `AMAP_KEY` and `APP_TOKEN` as platform secrets, never in the image or in git.

**Restrict the AMAP_KEY** in the AMap console to Web Service usage and, if available, to your server's egress IP, so a leaked key is less useful.

### 1.2 Test the Cloud Run

After the server is running, you can test the cloud run using the following example test case (the `SERVICE_URL` here assumes you use the google cloud run service):

```bash
SERVICE_URL="https://YOUR-SERVICE-URL.a.run.app"
APP_TOKEN="your-app-token"

curl -s "$SERVICE_URL/health"
echo

curl -s -X POST "$SERVICE_URL/analyze" \
  -H "content-type: application/json" \
  -H "x-app-token: $APP_TOKEN" \
  -d '{
    "driver": {"name": "A", "lon": 121.5086, "lat": 31.2454},
    "passenger": {"name": "B", "lon": 121.4737, "lat": 31.2304}
  }'
echo
```

---

## Part 2 — Bundle the app for a phone

### 2.1 Keys and config the app needs

Everything is injected at build time with `--dart-define`:

| Define              | Needed for                        | Notes                                         |
| ------------------- | --------------------------------- | --------------------------------------------- |
| `AMAP_IOS_KEY`      | iOS native map SDK                | Bound to your iOS bundle ID in the AMap console. |
| `AMAP_ANDROID_KEY`  | Android native map SDK            | Bound to your Android package name + SHA-1.   |
| `PICKUP_API_BASE`   | Talking to the backend            | e.g. `https://api.yourdomain.com` (no trailing slash). |
| `PICKUP_API_TOKEN`  | Passing the server's `APP_TOKEN`  | Sent as `X-App-Token`.                        |
| `AMAP_WEB_KEY`      | *Only* the on-device fallback path| Optional. Omit it to keep the Web Service key off the device entirely; the fallback then runs in estimates-only mode. |

> Note: `--dart-define` values are embedded in the app binary. `PICKUP_API_TOKEN`
> is therefore a low-trust gate (it deters casual abuse, not a determined
> reverse-engineer). Keep the real protection server-side: rate limits, the
> restricted `AMAP_KEY`, and monitoring. For stronger client auth later,
> add per-install tokens or App Attest / Play Integrity at the server.

### 2.2 iOS

Prerequisites: a Mac with Xcode, an Apple Developer account, an App ID whose
bundle identifier is registered as an AMap iOS key.

```bash
cd app/flutter

flutter build ipa --release \
  --dart-define=AMAP_IOS_KEY=$AMAP_IOS_KEY \
  --dart-define=PICKUP_API_BASE=https://api.yourdomain.com \
  --dart-define=PICKUP_API_TOKEN=$PICKUP_API_TOKEN
```

Then distribute the `.ipa` (in `build/ios/ipa/`) via TestFlight / the App Store:

- Open `ios/Runner.xcworkspace` in Xcode, set the Team and a unique Bundle
  Identifier, and enable automatic signing; **or** use `flutter build ipa
  --export-options-plist` with your provisioning profile.
- Upload with Xcode Organizer or `xcrun altool`/`Transporter` to App Store
  Connect, then release to TestFlight for device testing.

The app already declares the location usage strings and
`LSApplicationQueriesSchemes` (`iosamap`, `baidumap`) in
[`ios/Runner/Info.plist`](../app/flutter/ios/Runner/Info.plist). Since the app
now calls **your** HTTPS backend rather than AMap directly, no additional ATS
exception is required for optimization traffic.

### 2.3 Android

Prerequisites: an AMap Android key registered against your package name and the
signing certificate's SHA-1.

```bash
cd app/flutter

# App Bundle for Play:
flutter build appbundle --release \
  --dart-define=AMAP_ANDROID_KEY=$AMAP_ANDROID_KEY \
  --dart-define=PICKUP_API_BASE=https://api.yourdomain.com \
  --dart-define=PICKUP_API_TOKEN=$PICKUP_API_TOKEN

# or an APK for sideloading:
flutter build apk --release --dart-define=... (same defines)
```

- Configure release signing in `android/app/build.gradle` with a keystore (do
  not ship the debug key). The SHA-1 of that keystore must match the one you
  registered for the AMap Android key, or the map will fail to load.
- Upload the `.aab` (in `build/app/outputs/bundle/release/`) to the Play
  Console. Cleartext traffic isn't needed because the backend is HTTPS.

### 2.4 Verifying on a physical device

- With `PICKUP_API_BASE` set, tapping **Start Route Optimizing** should return a
  result whose header badge reads **Live traffic** (or **Live + estimates**) —
  proof the request went through the backend with a working `AMAP_KEY`.
- Turn the phone to airplane mode (or stop the server) and retry: the app should
  still produce a result via the on-device fallback with an **Estimates only**
  badge, confirming graceful degradation.
- Server-side, watch the logs / `X-Cache` header to confirm requests arrive and
  repeated ones are served from cache.

---

## Security checklist

- [ ] `AMAP_KEY` only in the server environment (never a `--dart-define`, never
      in git). Restrict it to Web Service + server IP in the AMap console.
- [ ] `APP_TOKEN` set to a long random value; app ships the matching
      `PICKUP_API_TOKEN`.
- [ ] Backend served over HTTPS only.
- [ ] Rate limiting / quota alerts in front of the backend (platform WAF,
      reverse proxy, or AMap console quota alarms).
- [ ] Map SDK keys locked to your exact bundle ID / package + signing cert.
