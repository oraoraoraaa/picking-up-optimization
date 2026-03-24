use anyhow::{ Context, Result };
use chrono::Utc;
use reqwest::blocking::Client;
use serde::Serialize;
use serde_json::Value;
use std::cmp::Ordering;
use std::env;
use std::time::Duration;

const DRIVING_URL: &str = "https://restapi.amap.com/v3/direction/driving";
const WALKING_URL: &str = "https://restapi.amap.com/v3/direction/walking";
const BICYCLING_URL: &str = "https://restapi.amap.com/v4/direction/bicycling";
const TRANSIT_URL: &str = "https://restapi.amap.com/v5/direction/transit/integrated";

#[derive(Clone, Debug)]
struct Point {
    name: &'static str,
    lon: f64,
    lat: f64,
}

#[derive(Clone, Copy, Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum MobilityMode {
    Walking,
    Bicycle,
    Transit,
}

#[derive(Clone, Debug)]
struct Candidate {
    name: &'static str,
    point: Point,
}

#[derive(Clone, Debug, Serialize)]
struct RankedOption {
    rank: usize,
    pickup_point: String,
    mode: MobilityMode,
    driver_eta_min: f64,
    passenger_eta_min: f64,
    total_eta_min: f64,
    rationale: String,
    pickup_lon: f64,
    pickup_lat: f64,
}

#[derive(Debug, Serialize)]
struct RecommendationSet {
    generated_at: String,
    data_source: String,
    passenger_start: Location,
    driver_start: Location,
    stay_put_option: StayPutOption,
    options: Vec<RankedOption>,
}

#[derive(Debug, Serialize)]
struct StayPutOption {
    driver_eta_min: f64,
    passenger_eta_min: f64,
    total_eta_min: f64,
    rationale: String,
}

#[derive(Debug, Serialize)]
struct Location {
    name: String,
    lon: f64,
    lat: f64,
}

#[derive(Debug)]
struct EvalResult {
    pickup_point: String,
    pickup_lon: f64,
    pickup_lat: f64,
    mode: MobilityMode,
    driver_eta_min: f64,
    passenger_eta_min: f64,
    total_eta_min: f64,
}

fn main() {
    if let Err(err) = run() {
        eprintln!("vertical-slice failed: {err:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let passenger = Point {
        name: "People's Square",
        lon: 121.4737,
        lat: 31.2304,
    };
    let driver = Point {
        name: "Lujiazui",
        lon: 121.5086,
        lat: 31.2454,
    };

    let candidates = vec![
        Candidate {
            name: "Current Pickup (Nanjing East Rd)",
            point: Point {
                name: "Nanjing East Rd",
                lon: 121.4849,
                lat: 31.2381,
            },
        },
        Candidate {
            name: "Alternative A (The Bund)",
            point: Point {
                name: "The Bund",
                lon: 121.4905,
                lat: 31.24,
            },
        },
        Candidate {
            name: "Alternative B (Xintiandi)",
            point: Point {
                name: "Xintiandi",
                lon: 121.4753,
                lat: 31.2193,
            },
        }
    ];

    let modes = [MobilityMode::Walking, MobilityMode::Bicycle, MobilityMode::Transit];
    let api_key = env::var("AMAP_KEY").ok();
    let client = Client::builder()
        .timeout(Duration::from_millis(1400))
        .build()
        .context("failed to build HTTP client")?;

    let mut evals = Vec::with_capacity(candidates.len() * modes.len());
    let mut successful_api_calls = 0usize;

    for candidate in &candidates {
        let driver_minutes = fetch_driver_minutes(
            &client,
            api_key.as_deref(),
            &driver,
            &candidate.point
        )
            .map(|v| {
                successful_api_calls += 1;
                v
            })
            .unwrap_or_else(|| fallback_eta_minutes(&driver, &candidate.point, 22.0));

        for mode in modes {
            let passenger_minutes = fetch_passenger_minutes(
                &client,
                api_key.as_deref(),
                mode,
                &passenger,
                &candidate.point
            )
                .map(|v| {
                    successful_api_calls += 1;
                    v
                })
                .unwrap_or_else(||
                    fallback_passenger_eta_minutes(mode, &passenger, &candidate.point)
                );

            evals.push(EvalResult {
                pickup_point: candidate.name.to_string(),
                pickup_lon: candidate.point.lon,
                pickup_lat: candidate.point.lat,
                mode,
                driver_eta_min: round2(driver_minutes),
                passenger_eta_min: round2(passenger_minutes),
                total_eta_min: round2(driver_minutes.max(passenger_minutes)),
            });
        }
    }

    evals.sort_by(|a, b| a.total_eta_min.partial_cmp(&b.total_eta_min).unwrap_or(Ordering::Equal));

    let stay_put_driver_eta_min = fetch_driver_minutes(
        &client,
        api_key.as_deref(),
        &driver,
        &passenger
    )
        .map(|v| {
            successful_api_calls += 1;
            v
        })
        .unwrap_or_else(|| fallback_eta_minutes(&driver, &passenger, 22.0));

    let stay_put_option = StayPutOption {
        driver_eta_min: round2(stay_put_driver_eta_min),
        passenger_eta_min: 0.0,
        total_eta_min: round2(stay_put_driver_eta_min.max(0.0)),
        rationale: "Passenger stays in place; driver goes directly to passenger location.".to_string(),
    };

    let baseline_total = evals
        .iter()
        .find(|item| item.pickup_point.contains("Current Pickup"))
        .map(|item| item.total_eta_min)
        .unwrap_or(0.0);

    let top3: Vec<RankedOption> = evals
        .into_iter()
        .take(3)
        .enumerate()
        .map(|(idx, item)| {
            let delta = baseline_total - item.total_eta_min;
            let rationale = if delta > 0.0 {
                format!(
                    "Saves {:.1} min vs baseline. Completion time is max(driver {:.1} min, passenger {:.1} min) with {:?}.",
                    delta,
                    item.driver_eta_min,
                    item.passenger_eta_min,
                    item.mode
                )
            } else {
                format!(
                    "Comparable to baseline. Completion time is max(driver {:.1} min, passenger {:.1} min) with {:?}.",
                    item.driver_eta_min,
                    item.passenger_eta_min,
                    item.mode
                )
            };

            RankedOption {
                rank: idx + 1,
                pickup_point: item.pickup_point,
                mode: item.mode,
                driver_eta_min: item.driver_eta_min,
                passenger_eta_min: item.passenger_eta_min,
                total_eta_min: item.total_eta_min,
                rationale,
                pickup_lon: item.pickup_lon,
                pickup_lat: item.pickup_lat,
            }
        })
        .collect();

    let data_source = (
        if api_key.is_some() && successful_api_calls > 0 {
            if successful_api_calls < candidates.len() * (modes.len() + 1) {
                "amap_with_fallback"
            } else {
                "amap"
            }
        } else {
            "fallback"
        }
    ).to_string();

    let payload = RecommendationSet {
        generated_at: Utc::now().to_rfc3339(),
        data_source,
        passenger_start: Location {
            name: passenger.name.to_string(),
            lon: passenger.lon,
            lat: passenger.lat,
        },
        driver_start: Location {
            name: driver.name.to_string(),
            lon: driver.lon,
            lat: driver.lat,
        },
        stay_put_option,
        options: top3,
    };

    println!("{}", serde_json::to_string_pretty(&payload)?);
    Ok(())
}

fn fetch_driver_minutes(
    client: &Client,
    key: Option<&str>,
    from: &Point,
    to: &Point
) -> Option<f64> {
    let key = key?;
    let params = [
        ("origin", to_lonlat(from)),
        ("destination", to_lonlat(to)),
        ("strategy", "0".to_string()),
        ("extensions", "all".to_string()),
        ("key", key.to_string()),
    ];
    fetch_duration_minutes(client, DRIVING_URL, &params)
}

fn fetch_passenger_minutes(
    client: &Client,
    key: Option<&str>,
    mode: MobilityMode,
    from: &Point,
    to: &Point
) -> Option<f64> {
    let key = key?;
    match mode {
        MobilityMode::Walking => {
            let params = [
                ("origin", to_lonlat(from)),
                ("destination", to_lonlat(to)),
                ("key", key.to_string()),
            ];
            fetch_duration_minutes(client, WALKING_URL, &params)
        }
        MobilityMode::Bicycle => {
            let params = [
                ("origin", to_lonlat(from)),
                ("destination", to_lonlat(to)),
                ("key", key.to_string()),
            ];
            fetch_duration_minutes(client, BICYCLING_URL, &params)
        }
        MobilityMode::Transit => {
            let params = [
                ("origin", to_lonlat(from)),
                ("destination", to_lonlat(to)),
                ("city1", "Shanghai".to_string()),
                ("city2", "Shanghai".to_string()),
                ("key", key.to_string()),
            ];
            fetch_duration_minutes(client, TRANSIT_URL, &params)
        }
    }
}

fn fetch_duration_minutes(client: &Client, url: &str, params: &[(&str, String)]) -> Option<f64> {
    let response = client.get(url).query(params).send().ok()?;
    let body: Value = response.json().ok()?;

    if body.get("status").and_then(Value::as_str) == Some("0") {
        return None;
    }

    // Amap endpoints return duration in different JSON paths; probe common layouts.
    let paths = ["/route/paths/0/duration", "/route/transits/0/duration", "/data/paths/0/duration"];

    for path in &paths {
        if let Some(value) = body.pointer(path).and_then(value_to_f64) {
            return Some(value / 60.0);
        }
    }

    None
}

fn fallback_passenger_eta_minutes(mode: MobilityMode, from: &Point, to: &Point) -> f64 {
    match mode {
        MobilityMode::Walking => fallback_eta_minutes(from, to, 4.8),
        MobilityMode::Bicycle => fallback_eta_minutes(from, to, 14.0),
        MobilityMode::Transit => fallback_eta_minutes(from, to, 22.0) + 4.0,
    }
}

fn fallback_eta_minutes(from: &Point, to: &Point, speed_kmh: f64) -> f64 {
    let distance_km = haversine_km(from.lat, from.lon, to.lat, to.lon);
    let raw = (distance_km / speed_kmh) * 60.0;
    raw.max(1.0)
}

fn to_lonlat(point: &Point) -> String {
    format!("{:.6},{:.6}", point.lon, point.lat)
}

fn value_to_f64(value: &Value) -> Option<f64> {
    if let Some(num) = value.as_f64() {
        return Some(num);
    }
    value.as_str()?.parse::<f64>().ok()
}

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

fn haversine_km(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    let radius_km = 6371.0;
    let dlat = (lat2 - lat1).to_radians();
    let dlon = (lon2 - lon1).to_radians();

    let a =
        (dlat / 2.0).sin().powi(2) +
        lat1.to_radians().cos() * lat2.to_radians().cos() * (dlon / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();

    radius_km * c
}
