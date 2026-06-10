//! CLI entry point for the pickup optimization core.
//!
//! Usage:
//!   pickup-op                # built-in Shanghai demo scenario
//!   pickup-op scenario.json  # scenario from a file
//!   pickup-op -              # scenario JSON from stdin
//!
//! Scenario format:
//!   {"driver": {"name": "Lujiazui", "lon": 121.5086, "lat": 31.2454},
//!    "passenger": {"name": "People's Square", "lon": 121.4737, "lat": 31.2304},
//!    "city": "上海"}
//!
//! Set AMAP_KEY to use live AMap routing; otherwise deterministic fallback
//! estimates keep the run reproducible.

use anyhow::{Context, Result};
use pickup_op::domain::{NamedPoint, Scenario};
use pickup_op::engine::EngineConfig;
use pickup_op::run_analysis;
use std::env;
use std::fs;
use std::io::Read;

fn main() {
    if let Err(err) = run() {
        eprintln!("pickup-op failed: {err:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let scenario = load_scenario().context("failed to load scenario")?;
    let api_key = env::var("AMAP_KEY").ok();
    let result = run_analysis(&scenario, api_key.as_deref(), &EngineConfig::default())?;
    println!("{}", serde_json::to_string_pretty(&result)?);
    Ok(())
}

fn load_scenario() -> Result<Scenario> {
    match env::args().nth(1).as_deref() {
        Some("-") => {
            let mut raw = String::new();
            std::io::stdin()
                .read_to_string(&mut raw)
                .context("failed to read stdin")?;
            serde_json::from_str(&raw).context("invalid scenario JSON on stdin")
        }
        Some(path) => {
            let raw = fs::read_to_string(path)
                .with_context(|| format!("failed to read scenario file {path}"))?;
            serde_json::from_str(&raw).with_context(|| format!("invalid scenario JSON in {path}"))
        }
        None => Ok(Scenario {
            driver: NamedPoint {
                name: "Lujiazui".to_string(),
                lon: 121.5086,
                lat: 31.2454,
            },
            passenger: NamedPoint {
                name: "People's Square".to_string(),
                lon: 121.4737,
                lat: 31.2304,
            },
            city: Some("上海".to_string()),
        }),
    }
}
