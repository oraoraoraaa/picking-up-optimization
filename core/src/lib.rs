//! Pickup optimization core: domain types, the route-interception engine,
//! and AMap adapters. The Flutter app's on-device service mirrors the
//! formulas in [`engine`]; keep both in sync when tuning.

pub mod amap;
pub mod domain;
pub mod engine;

use anyhow::{Context, Result};
use chrono::Utc;
use domain::{
    EvaluatedOption, GeoPoint, MobilityMode, RecommendationSet, Scenario, StayPutSuggestion,
    Suggestion,
};
use engine::EngineConfig;
use reqwest::blocking::Client;

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

/// Passenger start -> meeting point path for one suggestion. Walking and
/// bicycling have real path APIs; transit falls back to a straight line.
fn passenger_polyline(
    client: &Client,
    api_key: Option<&str>,
    mode: MobilityMode,
    passenger: GeoPoint,
    meeting_point: GeoPoint,
) -> Vec<GeoPoint> {
    let fetched = api_key.and_then(|key| match mode {
        MobilityMode::Walking => amap::fetch_walking_path(client, key, passenger, meeting_point),
        MobilityMode::Bicycle => {
            amap::fetch_bicycling_path(client, key, passenger, meeting_point)
        }
        MobilityMode::Transit => None,
    });

    fetched
        .map(|(_, polyline)| polyline)
        .filter(|polyline| polyline.len() >= 2)
        .unwrap_or_else(|| vec![passenger, meeting_point])
}

/// Reverse-geocode a meeting point to `(name, address)`. When no key/network
/// is available the name is empty and the address degrades to coordinates so
/// the UI always has something to show.
fn resolve_place(
    client: &Client,
    api_key: Option<&str>,
    point: GeoPoint,
) -> (String, String) {
    let place = api_key.and_then(|key| amap::fetch_place(client, key, point));
    match place {
        Some(p) => {
            let address = if p.address.is_empty() {
                format!("{:.5}, {:.5}", point.lon, point.lat)
            } else {
                p.address
            };
            (p.name, address)
        }
        None => (String::new(), format!("{:.5}, {:.5}", point.lon, point.lat)),
    }
}

#[allow(clippy::too_many_arguments)]
fn to_suggestion(
    option: &EvaluatedOption,
    recommended: bool,
    baseline_driver_eta_min: f64,
    meeting_point_name: String,
    meeting_point_address: String,
    driver_route_polyline: Vec<GeoPoint>,
    passenger_path_polyline: Vec<GeoPoint>,
) -> Suggestion {
    let saved = (baseline_driver_eta_min - option.driver_eta_min).max(0.0);
    Suggestion {
        mode: option.mode,
        recommended,
        meeting_point: option.meeting_point,
        meeting_point_name,
        meeting_point_address,
        driver_eta_min: round2(option.driver_eta_min),
        passenger_eta_min: round2(option.passenger_eta_min),
        completion_min: round2(option.completion_min),
        driver_saved_min: round2(saved),
        score: round2(option.score),
        rationale: format!(
            "Passenger can {} about {:.0} min to meet on the driver's route; \
             driver arrives in {:.0} min and saves {:.0} min of driving.",
            option.mode.label(),
            option.passenger_eta_min.ceil(),
            option.driver_eta_min.ceil(),
            saved.floor(),
        ),
        driver_route_polyline,
        passenger_path_polyline,
    }
}

/// Full analysis: fetch the driver's inbound route, generate interception
/// candidates, evaluate passenger modes, rank, and reduce to one displayable
/// suggestion per mode plus the stay-put plan. Exactly one entry across
/// `stay_put` and `suggestions` carries `recommended: true`.
pub fn run_analysis(
    scenario: &Scenario,
    api_key: Option<&str>,
    cfg: &EngineConfig,
) -> Result<RecommendationSet> {
    let client = amap::build_client().context("failed to build HTTP client")?;
    let driver = scenario.driver.point();
    let passenger = scenario.passenger.point();

    // Transit planning needs a citycode; when the caller did not supply a city
    // (the thin mobile client never does), derive it from the passenger.
    let effective_city = scenario
        .city
        .as_deref()
        .map(str::trim)
        .filter(|c| !c.is_empty())
        .map(str::to_string)
        .or_else(|| api_key.and_then(|key| amap::fetch_citycode(&client, key, passenger)));

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
                        effective_city.as_deref(),
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
    let switch_wins = engine::decide(baseline_driver_eta_min, &ranked, cfg).is_some();
    // Per-mode winners preserve rank order, so when a switch wins overall the
    // recommended option is exactly the first per-mode winner.
    let per_mode = engine::best_per_mode(&ranked);

    let suggestions: Vec<Suggestion> = per_mode
        .iter()
        .enumerate()
        .map(|(index, option)| {
            let driver_route_polyline: Vec<GeoPoint> = route.points[..=option.route_index]
                .iter()
                .map(|p| p.point)
                .collect();
            let passenger_path_polyline = passenger_polyline(
                &client,
                api_key,
                option.mode,
                passenger,
                option.meeting_point,
            );
            let (name, address) = resolve_place(&client, api_key, option.meeting_point);
            to_suggestion(
                option,
                switch_wins && index == 0,
                baseline_driver_eta_min,
                name,
                address,
                driver_route_polyline,
                passenger_path_polyline,
            )
        })
        .collect();

    // The stay-put meeting point is the passenger's location; prefer the
    // caller-supplied name, otherwise reverse-geocode it.
    let (stay_name, stay_address) = {
        let (resolved_name, address) = resolve_place(&client, api_key, passenger);
        let supplied = scenario.passenger.name.trim();
        let name = if supplied.is_empty() {
            resolved_name
        } else {
            supplied.to_string()
        };
        (name, address)
    };

    let stay_put = StayPutSuggestion {
        recommended: !switch_wins,
        driver_eta_min: round2(baseline_driver_eta_min),
        completion_min: round2(baseline_driver_eta_min),
        meeting_point_name: stay_name,
        meeting_point_address: stay_address,
        rationale: if switch_wins {
            "Driver goes all the way to the passenger's location.".to_string()
        } else {
            "Stay at the original pickup point — no alternative beats it by a \
             clear enough margin."
                .to_string()
        },
        driver_route_polyline: route.points.iter().map(|p| p.point).collect(),
    };

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
        stay_put,
        suggestions,
    })
}
