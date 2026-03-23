# Picking-Up Optimization Implementation Plan

## 1. Product Scope and Success Criteria

### What to do

- Define a clear V1 scope for PC and Android:
  - Passenger side: always re-calculate fastest pickup strategy from current conditions, suggest alternatives, show ETA tradeoffs.
  - Driver side (can be simulated in V1): route to selected pickup point and ETA updates.
  - Shared: map display, point selection, route comparison, and recommendation explanation.
- Define non-functional targets:
  - Suggestion latency target (for example, < 2.0s from request to ranked options).
  - Reliability target (for example, API call success > 99% with retries).
  - Accuracy target (for example, recommendation improves pickup ETA in historical replay scenarios by a measurable percentage).
- Define launch geography and language support (important for Amap API constraints).

### Why to do

- Prevents scope creep and keeps engineering focused on a shippable V1.
- Gives objective criteria for architecture and algorithm decisions.
- Reduces rework when moving from prototype to production.

### How to do

- Write a V1 requirements doc in `docs/v1-requirements.md` with user stories and acceptance criteria.
- Create a short KPI document in `docs/metrics.md` with baseline, target, and measurement method.
- Keep a strict “defer list” for V1.1+ features.

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

### What to do

- Restructure into a workspace that supports growth.
- Separate executable apps from reusable libraries.

### Why to do

- Avoids tight coupling and makes CI, testing, and packaging easier.
- Supports independent release cadence for engine and app.

### How to do

- Suggested structure:
  - `core/` Rust workspace root
  - `core/crates/domain` (entities, constraints, objective function)
  - `core/crates/engine` (candidate generation, optimization, ranking)
  - `core/crates/amap_client` (API integration + retries + rate-limit handling)
  - `core/crates/bindings` (flutter_rust_bridge exposed APIs)
  - `app/flutter/` Flutter app for desktop + Android
  - `docs/` architecture, API schemas, runbooks
  - `scripts/` dev tooling and code generation scripts
- Add architecture decision records in `docs/adr/`.

---

## 4. Domain Modeling and Optimization Objective

### What to do

- Model the core entities:
  - `Passenger`, `Driver`, `PickupPoint`, `RoadSegment`, `TrafficSnapshot`, `MobilityMode`, `TransitOption`.
- Define the optimization target and constraints:
  - Minimize total pickup completion time.
  - Penalize high uncertainty, unsafe locations, and excessive passenger detours.
- Build a recommendation scoring formula and ranking strategy.

### Why to do

- Optimization quality depends on clear objective design.
- Explicit constraints prevent unrealistic or unsafe suggestions.
- A documented scoring model is critical for debugging and product trust.

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

### Why to do

- External APIs are the largest reliability and latency risk.
- Proper caching and backoff prevent outages and quota burn.

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

### Why to do

- Recommendation quality starts with candidate quality.
- Poor candidates produce bad ranking regardless of algorithm.

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

## 8. Flutter App Layer (Desktop + Android First)

### What to do

- Build Flutter UI for map, recommendation list, and route comparisons.
- Integrate Rust core via bridge and async state updates.
- Keep platform-specific code isolated.

### Why to do

- Flutter enables high code reuse across desktop/mobile.
- Isolated platform channel code reduces future iOS migration effort.

### How to do

- App architecture:
  - Use a predictable state system (for example Riverpod or Bloc).
  - Introduce clean modules: `presentation`, `application`, `data`, `ffi`.
- UX flow:
  - Locate passenger and current pickup.
  - Fetch analysis.
  - Show ranked alternatives with ETA deltas, selected passenger mode, and rationale.
  - Allow passenger mode controls: auto, walk-only, bicycle-only, transit-only.
  - Let user accept/reject and re-run with constraints.
- Desktop target:
  - Prioritize macOS and Windows support first if resources are limited.

---

## 9. iOS Migration Readiness from Day 1

### What to do

- Design for iOS compatibility while not shipping iOS in first release.
- Avoid Android-only assumptions in core interfaces.

### Why to do

- Retrofitting iOS support later is expensive if architecture leaks platform specifics.

### How to do

- Keep `Rust Core` platform-agnostic (no Android SDK assumptions).
- Use Flutter plugin abstractions for location, permissions, and maps.
- For mapping stack, evaluate and document one of these paths:
  - Unified map abstraction in Flutter with platform-specific implementations.
  - Amap SDK on Android + iOS plugin parity check before locking interface.
- Add CI job that compiles iOS artifacts early (even before release) to catch drift.

---

## 10. Data, Privacy, and Security

### What to do

- Define what user location/route data is collected, retained, and transmitted.
- Implement secure secret handling and telemetry controls.

### Why to do

- Location data is highly sensitive and compliance-critical.
- Security mistakes here can block app store deployment and partnerships.

### How to do

- Data minimization:
  - Keep only fields needed for optimization and observability.
  - Apply retention windows and anonymization where possible.
- Security controls:
  - HTTPS-only transport.
  - Key rotation strategy for Amap credentials.
  - PII redaction in logs.
- Add privacy documentation in `docs/privacy.md`.

---

## 11. Testing Strategy (Core to UI)

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

---

## 12. Observability and Continuous Improvement

### What to do

- Add instrumentation for latency, API errors, recommendation acceptance, and ETA accuracy drift.
- Build mechanisms for offline evaluation and model/weight tuning.

### Why to do

- Real-world traffic behavior changes; static parameters degrade over time.
- Data-driven iteration is required for sustained quality.

### How to do

- Emit structured events from app and core:
  - request_started, recommendations_generated, recommendation_selected, pickup_completed.
- Build a weekly analysis pipeline for:
  - Improvement over baseline pickup.
  - False-improvement cases.
  - Regional performance differences.

---

## 13. DevEx, Build, and CI/CD

### What to do

- Establish reproducible local setup and automated pipelines for Rust + Flutter.
- Automate binding generation and compatibility checks.

### Why to do

- Hybrid stacks fail often due to tooling drift.
- Fast feedback loops improve delivery speed.

### How to do

- CI stages:
  - Rust format/lint/test (`fmt`, `clippy`, `test`).
  - Flutter analyze/test/build.
  - Flutter-Rust bridge codegen verification.
  - Packaging checks for desktop and Android artifacts.
- Add pre-commit hooks and scripts for one-command local validation.

---

## 14. Delivery Roadmap (Suggested)

### What to do

- Plan incremental milestones with demonstrable outputs.

### Why to do

- Reduces integration risk and keeps momentum visible.

### How to do

- Milestone 1: Foundations (1-2 weeks)
  - Workspace structure, Rust domain skeleton, Flutter shell app, bridge bootstrapped.
- Milestone 2: Data integration (2-3 weeks)
  - Amap client, caching/retries, basic route retrieval.
- Milestone 3: Optimization MVP (2-3 weeks)
  - Candidate generation, scoring, top-N recommendations.
- Milestone 4: Product flow completion (2 weeks)
  - End-to-end user flow, explanation UI, acceptance actions.
- Milestone 5: Hardening and release prep (2 weeks)
  - Performance tuning, failure handling, observability, packaging.

---

## 15. Immediate Next Actions (This Week)

### What to do

- Lock architecture and interfaces before deeper coding.
- Build vertical slice prototype quickly.

### Why to do

- Early integration catches boundary mistakes before they spread.

### How to do

- Create ADR-001 for architecture and ADR-002 for Flutter-Rust bridge choice.
- Implement a vertical slice:
  - Hardcoded passenger/driver locations.
  - Fetch traffic/route data from Amap.
  - Run simple scoring in Rust across baseline + alternatives and walk/bicycle/transit modes.
  - Display top 3 options in Flutter desktop app.
- Measure first meaningful latency and verify bridge stability.

---

## 16. Key Risks and Mitigations

### What to do

- Track major technical and product risks explicitly.

### Why to do

- Most delays in this product class come from external APIs and cross-platform integration.

### How to do

- Risk: Amap quota/performance instability.
  - Mitigation: aggressive caching, fallback mode, quota monitoring.
- Risk: Bridge complexity and DTO drift.
  - Mitigation: schema versioning and contract tests.
- Risk: Recommendation not trusted by users.
  - Mitigation: explainable reasons and confidence indicators.
- Risk: iOS migration friction later.
  - Mitigation: plugin abstraction + early iOS compile checks.

---

## 17. Definition of Done for V1

### What to do

- Set final criteria for release readiness.

### Why to do

- Ensures quality bar is objective and shared by engineering and product.

### How to do

- V1 is done when:
  - Desktop + Android app can run end-to-end with live Amap data.
  - Rust engine returns stable ranked alternatives under normal and degraded API conditions.
  - Observability dashboards show healthy latency and error budgets.
  - Security/privacy checklist is completed.
  - iOS build compatibility checks pass in CI (even if iOS app is not yet shipped).

---

## Suggested Technical Stack Snapshot

- Rust: `tokio`, `reqwest`, `serde`, `thiserror`, `rayon`, `tracing`
- Flutter: `riverpod` (or `bloc`), map plugin abstraction, platform secure storage
- Bridge: `flutter_rust_bridge`
- Testing: Rust unit/integration/property tests + Flutter widget/integration tests
- CI: GitHub Actions for matrix builds (desktop + Android + Rust checks)

This plan intentionally prioritizes a strong Rust decision core, fast cross-platform delivery through Flutter, and architecture decisions that keep iOS migration low-friction.