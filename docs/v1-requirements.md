# V1 Requirements

## Overview

Picking-Up Optimization is a tool designed to optimize the process of a driver picking up a passenger by continuously analyzing real-time traffic conditions and recalculating the fastest pickup strategy. The system suggests alternative pickup points and considers both driver and passenger travel times, supporting multiple passenger modes (walking, bicycle, transit). The project leverages the Amap API for map and traffic data.

## User Stories and Acceptance Criteria

### Passenger Side

- **Story:** As a passenger, I want the app to always recalculate the fastest pickup strategy based on current conditions, so I can minimize my waiting and transfer time.
  - **Acceptance Criteria:**
    - The app calculates and displays the fastest pickup point based on the current traffic conditions.
    - The app suggests alternative pickup points and shows ETA tradeoffs for each.
    - The passenger can view and select from suggested alternatives.

### Driver Side (Simulated in V1)

- **Story:** As a driver, I want to receive a route to the selected pickup point and get ETA updates, so I can efficiently reach the passenger.
  - **Acceptance Criteria:**
    - The app provides a route and ETA to the selected pickup point.
    - ETA updates are shown as conditions change.

### Shared Features

- **Story:** As a user (passenger or driver), I want to see a map, select points, compare routes, and understand why a recommendation was made. I also want to see the real-time location of both the driver and the passenger.
  - **Acceptance Criteria:**
    - The app displays a map with pickup points and routes.
    - Users can select and compare different pickup points/routes.
    - The app explains the rationale for each recommendation (e.g., ETA savings, mode used).

## Non-Functional Requirements

- **Suggestion Latency:** The system should return ranked pickup options within 2.0 seconds of a request.
- **Reliability:** API call success rate should exceed 99%, with retries for transient failures.
- **Accuracy:** Recommendations should measurably improve pickup ETA in historical replay scenarios.

## Out of Scope (V1.1+ Defer List)

- Features not critical for the V1 launch should be tracked in a defer list for future releases.

---

*This document defines the minimum requirements for the V1 release. All user stories must have clear acceptance criteria and be testable. Non-functional targets are mandatory for launch.*
