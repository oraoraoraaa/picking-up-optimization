//! Blocking AMap Web Service clients plus deterministic fallbacks.
//!
//! Every fetcher returns `Option` so the orchestrator can degrade to the
//! fallback estimators and keep the engine runnable without a key or network.

use crate::domain::{GeoPoint, MobilityMode, RoutePoint};
use crate::engine::haversine_m;
use reqwest::blocking::Client;
use serde_json::Value;
use std::time::Duration;

const DRIVING_URL: &str = "https://restapi.amap.com/v3/direction/driving";
const WALKING_URL: &str = "https://restapi.amap.com/v3/direction/walking";
const BICYCLING_URL: &str = "https://restapi.amap.com/v4/direction/bicycling";
const TRANSIT_URL: &str = "https://restapi.amap.com/v3/direction/transit/integrated";

/// Driving detour factor and speeds used by the fallback estimators.
const FALLBACK_DETOUR_FACTOR: f64 = 1.35;
const FALLBACK_DRIVING_KMH: f64 = 22.0;
const FALLBACK_WALKING_KMH: f64 = 4.8;
const FALLBACK_BICYCLE_KMH: f64 = 14.0;
const FALLBACK_TRANSIT_KMH: f64 = 20.0;
const FALLBACK_TRANSIT_OVERHEAD_MIN: f64 = 5.0;

pub struct DrivingRoute {
    pub points: Vec<RoutePoint>,
    pub total_secs: f64,
}

pub fn build_client() -> reqwest::Result<Client> {
    Client::builder().timeout(Duration::from_millis(3500)).build()
}

fn to_lonlat(point: GeoPoint) -> String {
    format!("{:.6},{:.6}", point.lon, point.lat)
}

fn parse_polyline(value: &str) -> Vec<GeoPoint> {
    value
        .split(';')
        .filter_map(|pair| {
            let mut it = pair.split(',');
            let lon = it.next()?.trim().parse::<f64>().ok()?;
            let lat = it.next()?.trim().parse::<f64>().ok()?;
            Some(GeoPoint { lon, lat })
        })
        .collect()
}

fn value_to_f64(value: &Value) -> Option<f64> {
    if let Some(num) = value.as_f64() {
        return Some(num);
    }
    value.as_str()?.parse::<f64>().ok()
}

fn get_json(client: &Client, url: &str, params: &[(&str, String)]) -> Option<Value> {
    let response = client.get(url).query(params).send().ok()?;
    let body: Value = response.json().ok()?;
    // v3 endpoints report failure via status="0"; v4 via errcode!=0.
    if body.get("status").and_then(Value::as_str) == Some("0") {
        return None;
    }
    if body.get("errcode").and_then(Value::as_i64).unwrap_or(0) != 0 {
        return None;
    }
    Some(body)
}

/// Fetch the driver's full driving route with per-vertex cumulative time,
/// distributing each step's duration proportionally over its segment lengths.
pub fn fetch_driving_route(
    client: &Client,
    key: &str,
    from: GeoPoint,
    to: GeoPoint,
) -> Option<DrivingRoute> {
    let params = [
        ("origin", to_lonlat(from)),
        ("destination", to_lonlat(to)),
        ("strategy", "0".to_string()),
        ("extensions", "all".to_string()),
        ("key", key.to_string()),
    ];
    let body = get_json(client, DRIVING_URL, &params)?;
    let steps = body.pointer("/route/paths/0/steps")?.as_array()?;

    let mut points: Vec<RoutePoint> = Vec::new();
    let mut elapsed_secs = 0.0;
    let mut traveled_m = 0.0;

    for step in steps {
        let step_secs = step.get("duration").and_then(value_to_f64)?;
        let polyline = step.get("polyline").and_then(Value::as_str)?;
        let vertices = parse_polyline(polyline);
        if vertices.len() < 2 {
            elapsed_secs += step_secs;
            continue;
        }

        let segment_lengths: Vec<f64> = vertices
            .windows(2)
            .map(|pair| haversine_m(pair[0], pair[1]))
            .collect();
        let step_length: f64 = segment_lengths.iter().sum();

        for (i, vertex) in vertices.iter().enumerate() {
            // Skip the joint vertex duplicated between consecutive steps.
            if i == 0 && points.last().map(|p: &RoutePoint| p.point) == Some(*vertex) {
                continue;
            }
            let progress: f64 = segment_lengths[..i].iter().sum();
            let fraction = if step_length > 0.0 { progress / step_length } else { 0.0 };
            points.push(RoutePoint {
                point: *vertex,
                driver_secs: elapsed_secs + step_secs * fraction,
                meters_from_start: traveled_m + progress,
            });
        }

        elapsed_secs += step_secs;
        traveled_m += step_length;
    }

    if points.len() < 2 {
        return None;
    }
    // Make the final vertex carry the full route duration.
    points.last_mut()?.driver_secs = elapsed_secs;
    Some(DrivingRoute {
        points,
        total_secs: elapsed_secs,
    })
}

/// Fetch the passenger's walking path: (duration secs, polyline).
pub fn fetch_walking_path(
    client: &Client,
    key: &str,
    from: GeoPoint,
    to: GeoPoint,
) -> Option<(f64, Vec<GeoPoint>)> {
    let params = [
        ("origin", to_lonlat(from)),
        ("destination", to_lonlat(to)),
        ("key", key.to_string()),
    ];
    let body = get_json(client, WALKING_URL, &params)?;
    let path = body.pointer("/route/paths/0")?;
    let secs = path.get("duration").and_then(value_to_f64)?;

    let mut polyline: Vec<GeoPoint> = Vec::new();
    if let Some(steps) = path.get("steps").and_then(Value::as_array) {
        for step in steps {
            if let Some(raw) = step.get("polyline").and_then(Value::as_str) {
                for vertex in parse_polyline(raw) {
                    if polyline.last() != Some(&vertex) {
                        polyline.push(vertex);
                    }
                }
            }
        }
    }
    Some((secs, polyline))
}

/// Fetch the passenger's bicycling path: (duration secs, polyline).
pub fn fetch_bicycling_path(
    client: &Client,
    key: &str,
    from: GeoPoint,
    to: GeoPoint,
) -> Option<(f64, Vec<GeoPoint>)> {
    let params = [
        ("origin", to_lonlat(from)),
        ("destination", to_lonlat(to)),
        ("key", key.to_string()),
    ];
    let body = get_json(client, BICYCLING_URL, &params)?;
    let path = body.pointer("/data/paths/0")?;
    let secs = path.get("duration").and_then(value_to_f64)?;

    let mut polyline: Vec<GeoPoint> = Vec::new();
    if let Some(steps) = path.get("steps").and_then(Value::as_array) {
        for step in steps {
            if let Some(raw) = step.get("polyline").and_then(Value::as_str) {
                for vertex in parse_polyline(raw) {
                    if polyline.last() != Some(&vertex) {
                        polyline.push(vertex);
                    }
                }
            }
        }
    }
    Some((secs, polyline))
}

/// Fetch the passenger's travel time in seconds for a given mode.
pub fn fetch_passenger_secs(
    client: &Client,
    key: &str,
    mode: MobilityMode,
    from: GeoPoint,
    to: GeoPoint,
    city: Option<&str>,
) -> Option<f64> {
    match mode {
        MobilityMode::Walking => fetch_walking_path(client, key, from, to).map(|(secs, _)| secs),
        MobilityMode::Bicycle => {
            fetch_bicycling_path(client, key, from, to).map(|(secs, _)| secs)
        }
        MobilityMode::Transit => {
            let city = city?;
            let params = [
                ("origin", to_lonlat(from)),
                ("destination", to_lonlat(to)),
                ("city", city.to_string()),
                ("key", key.to_string()),
            ];
            let body = get_json(client, TRANSIT_URL, &params)?;
            body.pointer("/route/transits/0/duration").and_then(value_to_f64)
        }
    }
}

/// Straight-line synthetic driving route used when AMap is unavailable.
pub fn fallback_driving_route(from: GeoPoint, to: GeoPoint) -> DrivingRoute {
    const VERTICES: usize = 32;
    let straight_m = haversine_m(from, to);
    let road_m = straight_m * FALLBACK_DETOUR_FACTOR;
    let total_secs = (road_m / 1000.0 / FALLBACK_DRIVING_KMH * 3600.0).max(60.0);

    let points = (0..VERTICES)
        .map(|i| {
            let t = i as f64 / (VERTICES - 1) as f64;
            RoutePoint {
                point: GeoPoint {
                    lon: from.lon + (to.lon - from.lon) * t,
                    lat: from.lat + (to.lat - from.lat) * t,
                },
                driver_secs: total_secs * t,
                meters_from_start: road_m * t,
            }
        })
        .collect();

    DrivingRoute { points, total_secs }
}

pub fn fallback_passenger_secs(mode: MobilityMode, from: GeoPoint, to: GeoPoint) -> f64 {
    let km = haversine_m(from, to) / 1000.0;
    let mins = match mode {
        MobilityMode::Walking => km / FALLBACK_WALKING_KMH * 60.0,
        MobilityMode::Bicycle => km / FALLBACK_BICYCLE_KMH * 60.0,
        MobilityMode::Transit => km / FALLBACK_TRANSIT_KMH * 60.0 + FALLBACK_TRANSIT_OVERHEAD_MIN,
    };
    mins.max(1.0) * 60.0
}
