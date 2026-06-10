//! Pickup optimization core: domain types, the route-interception engine,
//! and AMap adapters. The Flutter app's on-device service mirrors the
//! formulas in [`engine`]; keep both in sync when tuning weights.

pub mod amap;
pub mod domain;
pub mod engine;

use anyhow::{Context, Result};
use chrono::Utc;
use domain::{
    BaselineOption, EvaluatedOption, GeoPoint, MobilityMode, Recommendation, RecommendationSet,
    Scenario,
};
use engine::EngineConfig;

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

fn to_recommendation(option: &EvaluatedOption, baseline_driver_eta_min: f64) -> Recommendation {
    let saved = (baseline_driver_eta_min - option.driver_eta_min).max(0.0);
    Recommendation {
        stay_put: false,
        meeting_point: option.meeting_point,
        mode: Some(option.mode),
        driver_eta_min: round2(option.driver_eta_min),
        passenger_eta_min: round2(option.passenger_eta_min),
        completion_min: round2(option.completion_min),
        driver_saved_min: round2(saved),
        rationale: format!(
            "Passenger can {} about {:.0} min to meet on the driver's route; \
             driver arrives in {:.0} min and saves {:.0} min of driving.",
            option.mode.label(),
            option.passenger_eta_min.ceil(),
            option.driver_eta_min.ceil(),
            saved.floor(),
        ),
    }
}

/// Full analysis: fetch the driver's inbound route, generate interception
/// candidates, evaluate passenger modes, rank, and decide versus stay-put.
pub fn run_analysis(
    scenario: &Scenario,
    api_key: Option<&str>,
    cfg: &EngineConfig,
) -> Result<RecommendationSet> {
    let client = amap::build_client().context("failed to build HTTP client")?;
    let driver = scenario.driver.point();
    let passenger = scenario.passenger.point();

    let mut used_amap = false;
    let mut used_fallback = false;

    let route = api_key
        .and_then(|key| amap::fetch_driving_route(&client, key, driver, passenger))
        .inspect(|_| used_amap = true)
        .unwrap_or_else(|| {
            used_fallback = true;
            amap::fallback_driving_route(driver, passenger)
        });

    let baseline_driver_eta_min = route.total_secs / 60.0;
    let candidates = engine::generate_route_candidates(&route.points, passenger, cfg);

    let mut evaluated = Vec::new();
    for candidate in &candidates {
        for mode in engine::reachable_modes(candidate.passenger_straight_m, cfg) {
            let passenger_secs = api_key
                .and_then(|key| {
                    amap::fetch_passenger_secs(
                        &client,
                        key,
                        mode,
                        passenger,
                        candidate.point,
                        scenario.city.as_deref(),
                    )
                })
                .inspect(|_| used_amap = true)
                .unwrap_or_else(|| {
                    used_fallback = true;
                    amap::fallback_passenger_secs(mode, passenger, candidate.point)
                });

            let passenger_eta_min = passenger_secs / 60.0;
            evaluated.push(EvaluatedOption {
                meeting_point: candidate.point,
                route_index: candidate.route_index,
                mode,
                driver_eta_min: candidate.driver_eta_min,
                passenger_eta_min,
                completion_min: candidate.driver_eta_min.max(passenger_eta_min),
                score: engine::score_option(candidate.driver_eta_min, passenger_eta_min, mode, cfg),
            });
        }
    }

    let ranked = engine::rank_options(evaluated);
    let winner = engine::decide(baseline_driver_eta_min, &ranked, cfg);

    let full_polyline: Vec<GeoPoint> = route.points.iter().map(|p| p.point).collect();

    let (best, driver_route_polyline, passenger_path_polyline) = match winner {
        Some(option) => {
            let driver_polyline: Vec<GeoPoint> = route.points[..=option.route_index]
                .iter()
                .map(|p| p.point)
                .collect();
            let passenger_polyline = if option.mode == MobilityMode::Walking {
                api_key
                    .and_then(|key| {
                        amap::fetch_walking_path(&client, key, passenger, option.meeting_point)
                    })
                    .map(|(_, polyline)| polyline)
                    .filter(|polyline| polyline.len() >= 2)
            } else {
                None
            }
            .unwrap_or_else(|| vec![passenger, option.meeting_point]);

            (
                to_recommendation(option, baseline_driver_eta_min),
                driver_polyline,
                passenger_polyline,
            )
        }
        None => (
            Recommendation {
                stay_put: true,
                meeting_point: passenger,
                mode: None,
                driver_eta_min: round2(baseline_driver_eta_min),
                passenger_eta_min: 0.0,
                completion_min: round2(baseline_driver_eta_min),
                driver_saved_min: 0.0,
                rationale: "Stay at the original pickup point — no alternative beats it by a \
                            clear enough margin."
                    .to_string(),
            },
            full_polyline,
            Vec::new(),
        ),
    };

    let alternatives: Vec<Recommendation> = ranked
        .iter()
        .skip(if winner.is_some() { 1 } else { 0 })
        .take(2)
        .map(|option| to_recommendation(option, baseline_driver_eta_min))
        .collect();

    let data_source = match (used_amap, used_fallback) {
        (true, false) => "amap",
        (true, true) => "amap_with_fallback",
        _ => "fallback",
    };

    Ok(RecommendationSet {
        generated_at: Utc::now().to_rfc3339(),
        data_source: data_source.to_string(),
        passenger_start: scenario.passenger.clone(),
        driver_start: scenario.driver.clone(),
        baseline: BaselineOption {
            driver_eta_min: round2(baseline_driver_eta_min),
            completion_min: round2(baseline_driver_eta_min),
        },
        best,
        alternatives,
        driver_route_polyline,
        passenger_path_polyline,
    })
}
