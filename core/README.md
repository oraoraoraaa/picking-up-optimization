# The Rust Core

The core RUST implementation like domain, optimization engine, scoring, route fusion, caching policy, etc. should be put in this directory.

## Structure

| File | Responsibility |
| --- | --- |
| `src/domain.rs` | Shared DTOs (`GeoPoint`, `MobilityMode`, `RecommendationSet`, `Scenario`, ...) |
| `src/engine.rs` | Route-interception algorithm v1: candidate generation, weighted scoring, ranking, stay-put decision. Pure and unit-tested. |
| `src/amap.rs` | Blocking AMap Web Service clients (driving/walking/bicycling/transit) + deterministic fallbacks |
| `src/lib.rs` | `run_analysis` orchestrator tying route fetch → candidates → evaluation → recommendation |
| `src/main.rs` | Thin CLI entry point |

## The Algorithm (v1)

Meeting points are sampled along the driver's inbound route within the passenger's reach (walk/bicycle/transit gated by distance), then each candidate-mode pair is scored with:

```text
score = max(driver_eta, passenger_eta) + 0.15 * passenger_eta + mode_penalty
```

The best option must beat the stay-put baseline by at least 1.5 minutes, otherwise the engine recommends keeping the original pickup point. See `docs/IMPLEMENTATION.md` for the full description.

> The Flutter app currently runs a documented Dart mirror of this engine on-device (`app/flutter/lib/src/pickup_optimizer.dart`) until the FFI bridge lands. Keep weights and rules in sync when tuning.

## Run It

```bash
cd core
cargo test         # engine unit tests
cargo run --quiet  # built-in Shanghai demo scenario, JSON to stdout
```

Custom scenario from a file or stdin:

```bash
cargo run --quiet -- scenario.json
echo '{"driver":{"lon":121.5086,"lat":31.2454},"passenger":{"lon":121.4737,"lat":31.2304},"city":"上海"}' \
  | cargo run --quiet -- -
```

Optional key setup (otherwise deterministic fallback estimates are used):

```bash
export AMAP_KEY="your_amap_web_service_key"
```

## Contributor Rule

1. Make sure you fully understand where you should modify or add new files.

2. Be 100% clear about how your incoming changes are working with the current related code.

3. Write proper documentation describing your modification, and how it works with the current code in proper place (comments, PRs, etc.).

4. If an appropriate category folder does not exist, create a new one for your code and add a README.md that follows the same guidance style.
