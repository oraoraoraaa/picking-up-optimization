//! Route-interception optimization engine.
//!
//! Algorithm (v1):
//! 1. Take the driver's inbound route to the passenger's current location.
//! 2. Generate meeting-point candidates on that route: vertices the passenger
//!    can realistically reach (mode-gated by straight-line distance) and that
//!    still save the driver a meaningful amount of driving.
//! 3. Score every candidate-mode combination with a weighted objective:
//!    `score = max(driver_eta, passenger_eta) + w_burden * passenger_eta + mode_penalty`
//! 4. Rank ascending and recommend the winner only when it beats the
//!    stay-put baseline by a minimum improvement margin.
//!
//! Everything in this module is pure so it stays unit-testable; network
//! concerns live in [`crate::amap`].

use crate::domain::{Candidate, EvaluatedOption, GeoPoint, MobilityMode, RoutePoint};

#[derive(Clone, Debug)]
pub struct EngineConfig {
    /// Cap on candidates evaluated per run (controls API fan-out).
    pub max_candidates: usize,
    /// Minimum straight-line spacing between two candidates.
    pub min_candidate_spacing_m: f64,
    /// Moves shorter than this are not worth asking the passenger to make.
    pub min_passenger_move_m: f64,
    pub walk_reach_m: f64,
    pub bicycle_reach_m: f64,
    pub transit_reach_m: f64,
    /// Transit only makes sense above this distance.
    pub transit_min_m: f64,
    /// A candidate must save the driver at least this much driving time.
    pub min_driver_saving_secs: f64,
    /// Weight of the passenger's effort in the objective.
    pub passenger_burden_weight: f64,
    pub bicycle_penalty_min: f64,
    pub transit_penalty_min: f64,
    /// The winner must beat the stay-put baseline by this many minutes.
    pub min_improvement_min: f64,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            max_candidates: 4,
            min_candidate_spacing_m: 250.0,
            min_passenger_move_m: 120.0,
            walk_reach_m: 1200.0,
            bicycle_reach_m: 3500.0,
            transit_reach_m: 8000.0,
            transit_min_m: 2000.0,
            min_driver_saving_secs: 60.0,
            passenger_burden_weight: 0.15,
            bicycle_penalty_min: 1.0,
            transit_penalty_min: 2.5,
            min_improvement_min: 1.5,
        }
    }
}

pub fn haversine_m(a: GeoPoint, b: GeoPoint) -> f64 {
    let radius_m = 6_371_000.0;
    let dlat = (b.lat - a.lat).to_radians();
    let dlon = (b.lon - a.lon).to_radians();
    let h = (dlat / 2.0).sin().powi(2)
        + a.lat.to_radians().cos() * b.lat.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    2.0 * radius_m * h.sqrt().asin()
}

/// Generate meeting-point candidates along the driver's inbound route.
///
/// Vertices qualify when the passenger can reach them (within the widest mode
/// reach), the move is non-trivial, and stopping there still saves the driver
/// `min_driver_saving_secs` of driving. Qualifying vertices are then spaced
/// out greedily in route order and downsampled evenly to `max_candidates`
/// so the evaluated set spreads across the route instead of clustering.
pub fn generate_route_candidates(
    route: &[RoutePoint],
    passenger: GeoPoint,
    cfg: &EngineConfig,
) -> Vec<Candidate> {
    let Some(last) = route.last() else {
        return Vec::new();
    };
    let total_secs = last.driver_secs;

    let eligible = route.iter().enumerate().filter_map(|(index, vertex)| {
        let passenger_straight_m = haversine_m(vertex.point, passenger);
        if passenger_straight_m < cfg.min_passenger_move_m {
            return None;
        }
        if passenger_straight_m > cfg.transit_reach_m {
            return None;
        }
        if total_secs - vertex.driver_secs < cfg.min_driver_saving_secs {
            return None;
        }
        Some(Candidate {
            route_index: index,
            point: vertex.point,
            driver_eta_min: vertex.driver_secs / 60.0,
            passenger_straight_m,
        })
    });

    let mut spaced: Vec<Candidate> = Vec::new();
    for candidate in eligible {
        let far_enough = spaced
            .iter()
            .all(|kept| haversine_m(kept.point, candidate.point) >= cfg.min_candidate_spacing_m);
        if far_enough {
            spaced.push(candidate);
        }
    }

    if spaced.len() <= cfg.max_candidates {
        return spaced;
    }

    // Even downsample across the spaced list to keep route coverage.
    (0..cfg.max_candidates)
        .map(|slot| {
            let index = slot * (spaced.len() - 1) / (cfg.max_candidates - 1).max(1);
            spaced[index]
        })
        .collect()
}

/// Modes the passenger can plausibly use for a move of `distance_m`.
pub fn reachable_modes(distance_m: f64, cfg: &EngineConfig) -> Vec<MobilityMode> {
    let mut modes = Vec::new();
    if distance_m <= cfg.walk_reach_m {
        modes.push(MobilityMode::Walking);
    }
    if distance_m <= cfg.bicycle_reach_m {
        modes.push(MobilityMode::Bicycle);
    }
    if distance_m >= cfg.transit_min_m && distance_m <= cfg.transit_reach_m {
        modes.push(MobilityMode::Transit);
    }
    modes
}

pub fn mode_penalty_min(mode: MobilityMode, cfg: &EngineConfig) -> f64 {
    match mode {
        MobilityMode::Walking => 0.0,
        MobilityMode::Bicycle => cfg.bicycle_penalty_min,
        MobilityMode::Transit => cfg.transit_penalty_min,
    }
}

/// Weighted objective; lower is better. Completion time dominates, passenger
/// effort and mode friction act as tie-shifting penalties.
pub fn score_option(
    driver_eta_min: f64,
    passenger_eta_min: f64,
    mode: MobilityMode,
    cfg: &EngineConfig,
) -> f64 {
    let completion_min = driver_eta_min.max(passenger_eta_min);
    completion_min + cfg.passenger_burden_weight * passenger_eta_min + mode_penalty_min(mode, cfg)
}

/// Sort ascending by score; tie-break on lower passenger effort, then lower
/// driver ETA, so equal scores favor the least disruptive option.
pub fn rank_options(mut options: Vec<EvaluatedOption>) -> Vec<EvaluatedOption> {
    options.sort_by(|a, b| {
        (a.score, a.passenger_eta_min, a.driver_eta_min)
            .partial_cmp(&(b.score, b.passenger_eta_min, b.driver_eta_min))
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    options
}

/// Pick the winner among ranked options, or `None` when staying put wins.
///
/// The stay-put baseline has zero passenger effort, so its score is simply
/// the driver's full ETA. An alternative must beat that by
/// `min_improvement_min` to be worth the coordination overhead.
pub fn decide<'a>(
    baseline_driver_eta_min: f64,
    ranked: &'a [EvaluatedOption],
    cfg: &EngineConfig,
) -> Option<&'a EvaluatedOption> {
    let baseline_score = baseline_driver_eta_min;
    ranked
        .first()
        .filter(|best| best.score <= baseline_score - cfg.min_improvement_min)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn straight_route(from: GeoPoint, to: GeoPoint, vertices: usize, total_secs: f64) -> Vec<RoutePoint> {
        let total_m = haversine_m(from, to);
        (0..vertices)
            .map(|i| {
                let t = i as f64 / (vertices - 1) as f64;
                RoutePoint {
                    point: GeoPoint {
                        lon: from.lon + (to.lon - from.lon) * t,
                        lat: from.lat + (to.lat - from.lat) * t,
                    },
                    driver_secs: total_secs * t,
                    meters_from_start: total_m * t,
                }
            })
            .collect()
    }

    const LUJIAZUI: GeoPoint = GeoPoint { lon: 121.5086, lat: 31.2454 };
    const PEOPLES_SQUARE: GeoPoint = GeoPoint { lon: 121.4737, lat: 31.2304 };

    #[test]
    fn haversine_matches_known_distance() {
        // Lujiazui <-> People's Square is roughly 3.7 km straight-line.
        let d = haversine_m(LUJIAZUI, PEOPLES_SQUARE);
        assert!((3_000.0..4_500.0).contains(&d), "got {d}");
    }

    #[test]
    fn candidates_respect_reach_spacing_and_cap() {
        let cfg = EngineConfig::default();
        let route = straight_route(LUJIAZUI, PEOPLES_SQUARE, 60, 1200.0);
        let candidates = generate_route_candidates(&route, PEOPLES_SQUARE, &cfg);

        assert!(!candidates.is_empty());
        assert!(candidates.len() <= cfg.max_candidates);
        for c in &candidates {
            assert!(c.passenger_straight_m >= cfg.min_passenger_move_m);
            assert!(c.passenger_straight_m <= cfg.transit_reach_m);
        }
        for pair in candidates.windows(2) {
            assert!(haversine_m(pair[0].point, pair[1].point) >= cfg.min_candidate_spacing_m);
        }
    }

    #[test]
    fn candidates_must_save_driver_time() {
        let cfg = EngineConfig::default();
        let route = straight_route(LUJIAZUI, PEOPLES_SQUARE, 60, 1200.0);
        let candidates = generate_route_candidates(&route, PEOPLES_SQUARE, &cfg);
        let total_secs = route.last().unwrap().driver_secs;
        for c in &candidates {
            assert!(total_secs - c.driver_eta_min * 60.0 >= cfg.min_driver_saving_secs);
        }
    }

    #[test]
    fn empty_route_yields_no_candidates() {
        let cfg = EngineConfig::default();
        assert!(generate_route_candidates(&[], PEOPLES_SQUARE, &cfg).is_empty());
    }

    #[test]
    fn mode_gating_by_distance() {
        let cfg = EngineConfig::default();
        assert_eq!(
            reachable_modes(500.0, &cfg),
            vec![MobilityMode::Walking, MobilityMode::Bicycle]
        );
        assert_eq!(
            reachable_modes(2_500.0, &cfg),
            vec![MobilityMode::Bicycle, MobilityMode::Transit]
        );
        assert_eq!(reachable_modes(6_000.0, &cfg), vec![MobilityMode::Transit]);
        assert!(reachable_modes(10_000.0, &cfg).is_empty());
    }

    fn option(mode: MobilityMode, driver: f64, passenger: f64, cfg: &EngineConfig) -> EvaluatedOption {
        EvaluatedOption {
            meeting_point: PEOPLES_SQUARE,
            route_index: 0,
            mode,
            driver_eta_min: driver,
            passenger_eta_min: passenger,
            completion_min: driver.max(passenger),
            score: score_option(driver, passenger, mode, cfg),
        }
    }

    fn option_with_score(score: f64, driver: f64, passenger: f64) -> EvaluatedOption {
        EvaluatedOption {
            meeting_point: PEOPLES_SQUARE,
            route_index: 0,
            mode: MobilityMode::Walking,
            driver_eta_min: driver,
            passenger_eta_min: passenger,
            completion_min: driver.max(passenger),
            score,
        }
    }

    #[test]
    fn ranking_prefers_lower_score_then_lower_passenger_effort() {
        let worst = option_with_score(20.0, 18.0, 5.0);
        let tie_lazy = option_with_score(11.0, 10.0, 3.0);
        let tie_busy = option_with_score(11.0, 6.0, 9.0);
        let best = option_with_score(9.0, 8.0, 4.0);

        let ranked = rank_options(vec![worst, tie_busy, tie_lazy, best]);
        assert_eq!(ranked[0].score, 9.0);
        // Tie resolves toward the lower passenger effort.
        assert_eq!(ranked[1].passenger_eta_min, 3.0);
        assert_eq!(ranked[2].passenger_eta_min, 9.0);
        assert_eq!(ranked[3].score, 20.0);
    }

    #[test]
    fn scoring_penalizes_heavier_modes() {
        let cfg = EngineConfig::default();
        let walk = score_option(10.0, 5.0, MobilityMode::Walking, &cfg);
        let bike = score_option(10.0, 5.0, MobilityMode::Bicycle, &cfg);
        let transit = score_option(10.0, 5.0, MobilityMode::Transit, &cfg);
        assert!(walk < bike && bike < transit);
    }

    #[test]
    fn decide_keeps_stay_put_without_clear_improvement() {
        let cfg = EngineConfig::default();
        // Baseline 12 min; option completes in 11.5 but with burden the score
        // does not clear the 1.5 min improvement bar.
        let marginal = option(MobilityMode::Walking, 11.5, 6.0, &cfg);
        let ranked = rank_options(vec![marginal]);
        assert!(decide(12.0, &ranked, &cfg).is_none());
    }

    #[test]
    fn decide_picks_clear_winner() {
        let cfg = EngineConfig::default();
        let strong = option(MobilityMode::Walking, 7.0, 5.0, &cfg);
        let ranked = rank_options(vec![strong]);
        let best = decide(12.0, &ranked, &cfg).expect("should beat baseline");
        assert_eq!(best.driver_eta_min, 7.0);
    }

    #[test]
    fn decide_handles_empty_options() {
        let cfg = EngineConfig::default();
        assert!(decide(12.0, &[], &cfg).is_none());
    }
}
