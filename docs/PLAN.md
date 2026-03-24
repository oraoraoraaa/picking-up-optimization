# Picking-Up Optimization Implementation Plan

## Immediate Next Actions

### What to do

- Build vertical slice prototype quickly.

### How to do

- Implement a vertical slice:
  - Hardcoded passenger/driver locations.
  - Fetch traffic/route data from Amap.
  - Run simple scoring in Rust across baseline + alternatives and walk/bicycle/transit modes.
  - Display top 3 options in Flutter desktop app.
- Measure first meaningful latency and verify bridge stability.

---

> ![miku_support](https://github.com/user-attachments/assets/461ada5a-7fd9-4a00-980a-fc94eec6e150)

## 1. Product Scope and Success Criteria (DONE)

See [`docs/v1-requirements.md`](https://github.com/oraoraoraaa/picking-up-optimization/blob/main/docs/v1-requirements.md) for this step.

---

## 2. System Architecture (Rust Core + Flutter App)

### What to do

- Adopt a layered architecture:
  - `Rust Core` (domain, optimization engine, scoring, route fusion, caching policy).
  - `Infra adapters` (Amap API client, telemetry sinks, persistence abstractions).
  - `Flutter app` (UI, map interaction, state management, platform features).
- Define interface boundaries between Flutter and Rust.
- Decide data contracts for requests and responses.

### Why to do

- Keeps heavy logic and performance-critical pieces in Rust.
- Makes logic testable independently from UI.
- Enables platform expansion (iOS) with minimal business-logic rewrite.

### How to do

- Use `flutter_rust_bridge` for Flutter <-> Rust communication.
- Keep Rust API surface stable and versioned:
  - `analyze_pickup_scenario(input) -> RecommendationSet`
  - `recompute_fastest_pickup(input) -> RecommendationSet`
  - `recompute_with_constraints(input, constraints) -> RecommendationSet`
- Use serialization-safe DTOs (for example via `serde`) and avoid leaking infrastructure types into app layer.

---

## 3. Repository and Module Layout

- See [`docs/adr/`](https://github.com/oraoraoraaa/picking-up-optimization/blob/main/docs/adr).

---

## 4. Domain Modeling and Optimization Objective

### What to do

- Model the core entities:
  - `Passenger`, `Driver`, `PickupPoint`, `RoadSegment`, `TrafficSnapshot`, `MobilityMode`, `TransitOption`.
- Define the optimization target and constraints:
  - Minimize total pickup completion time.
  - Penalize high uncertainty, unsafe locations, and excessive passenger detours.
- Build a recommendation scoring formula and ranking strategy.

### How to do

- Define an objective function like:
  - `score = w1 * driver_eta + w2 * passenger_eta(mode) + w3 * congestion_risk + w4 * safety_penalty + w5 * uncertainty + w6 * mode_switch_penalty`
- Calibrate weights using replay data and controlled experiments.
- Build deterministic fallback logic when some signals are missing.

---

## 5. Amap Integration Strategy

### What to do

- Implement resilient Amap API clients for:
  - Geocoding/reverse geocoding
  - Driving route + traffic
  - Walking/bicycle/transit route
  - Nearby POI or candidate waypoint retrieval
- Build request throttling, retries, and caching.

### How to do

- In Rust `amap_client` crate:
  - Define typed request/response structs.
  - Add retry policy with exponential backoff + jitter.
  - Add circuit breaker behavior for repeated failures.
  - Add in-memory + optional disk cache with TTL per endpoint.
- Store secrets securely:
  - Android: secure storage + env-injected build configs.
  - Desktop: OS keychain where feasible; avoid plain-text keys.

---

## 6. Candidate Pickup Point Generation

### What to do

- Generate a set of feasible pickup strategies (keep current point or switch to alternatives).
- Filter out unsafe, inaccessible, or policy-disallowed points.

### How to do

- Candidate generation pipeline:
  - Include current pickup point as a baseline candidate in every run.
  - Build search radius rings around passenger location.
  - Collect candidates from map graph features and POIs.
  - Remove points violating mode-specific constraints (walking, bicycle, transit), lane access, or road restrictions.
- Add explainability metadata per candidate:
  - “3 min less total, passenger uses bicycle for 6 min, lower congestion risk on driver segment.”

---

## 7. Optimization and Ranking Engine in Rust

### What to do

- Evaluate each candidate-mode combination using travel-time estimates and risk measures.
- Rank and return top N recommendations with explanation fields.

### Why to do

- Core value of product is the decision quality and speed.
- Rust provides predictable performance and memory safety.

### How to do

- Engine design:
  - Parallel candidate evaluation via `rayon` where beneficial.
  - Normalize heterogeneous metrics before weighted sum.
  - Choose best passenger mode per candidate (walk/bicycle/transit) or enforce user-selected mode constraint.
  - Add tie-breakers (stability, route simplicity, passenger burden).
- Include robustness logic:
  - If API partial failure occurs, degrade gracefully with confidence score.
  - Return baseline recommendation (current pickup point) when alternatives are low confidence.

---

## 8. Testing Strategy (Core to UI)

### What to do

- Implement multi-layer tests:
  - Rust unit/integration/property tests for engine correctness.
  - Contract tests for Flutter-Rust bridge DTO compatibility.
  - Flutter widget/integration tests for critical flows.
  - Replay tests on recorded traffic scenarios.

### Why to do

- Optimization systems fail silently without robust validation.
- Cross-language boundaries are a common source of runtime bugs.

### How to do

- Rust:
  - Unit tests for scoring and constraints.
  - Property tests for invariants (for example, no recommendation violates hard constraints).
- End-to-end:
  - Golden scenario suite with expected ranking patterns.
  - Synthetic outage tests for Amap partial failures.
- Define quality gates in CI (coverage and regression checks).
