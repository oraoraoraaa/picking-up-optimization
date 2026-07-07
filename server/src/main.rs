//! Thin HTTP gateway around the pickup-optimization core.
//!
//! The mobile app posts a scenario (driver + passenger coordinates); the
//! server holds the AMap Web Service key, runs the Rust engine, and returns a
//! display-ready `RecommendationSet`. This keeps the billable Web Service key
//! off end-user devices and lets us cache identical requests across users.
//!
//! Configuration (environment variables):
//!   AMAP_KEY        AMap Web Service key. Without it the engine degrades to
//!                   deterministic estimates (data_source: "fallback").
//!   APP_TOKEN       Optional shared secret. When set, every /analyze request
//!                   must send it as the `X-App-Token` header, or get 401.
//!   PORT            Listen port (default 8080).
//!   CACHE_TTL_SECS  How long an identical analysis is reused (default 60).
//!                   Short because it captures live traffic.
//!   BIND_ADDR       Listen address (default 0.0.0.0).

use std::collections::HashMap;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use pickup_op::domain::Scenario;
use pickup_op::engine::EngineConfig;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

/// A cached, already-serialized analysis response.
struct CacheEntry {
    expires: Instant,
    body: String,
}

struct AppState {
    amap_key: Option<String>,
    app_token: Option<String>,
    cache_ttl: Duration,
    cache: Mutex<HashMap<String, CacheEntry>>,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "pickup_op_server=info,tower_http=info".into()),
        )
        .init();

    let amap_key = non_empty_env("AMAP_KEY");
    let app_token = non_empty_env("APP_TOKEN");
    let cache_ttl = Duration::from_secs(
        non_empty_env("CACHE_TTL_SECS")
            .and_then(|v| v.parse().ok())
            .unwrap_or(60),
    );
    let port: u16 = non_empty_env("PORT")
        .and_then(|v| v.parse().ok())
        .unwrap_or(8080);
    let bind_addr = non_empty_env("BIND_ADDR").unwrap_or_else(|| "0.0.0.0".to_string());

    if amap_key.is_none() {
        tracing::warn!("AMAP_KEY not set — responses will use fallback estimates only");
    }
    if app_token.is_none() {
        tracing::warn!("APP_TOKEN not set — /analyze is open to any caller");
    }

    let state = Arc::new(AppState {
        amap_key,
        app_token,
        cache_ttl,
        cache: Mutex::new(HashMap::new()),
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/analyze", post(analyze))
        .layer(TraceLayer::new_for_http())
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state);

    let addr: SocketAddr = format!("{bind_addr}:{port}")
        .parse()
        .expect("invalid BIND_ADDR/PORT");
    tracing::info!("pickup-op-server listening on http://{addr}");

    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .expect("failed to bind");
    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .expect("server error");
}

async fn health() -> &'static str {
    "ok"
}

/// Error type that renders as a JSON body with an appropriate status code.
struct AppError {
    status: StatusCode,
    message: String,
}

impl AppError {
    fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let body = Json(serde_json::json!({ "error": self.message }));
        (self.status, body).into_response()
    }
}

async fn analyze(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(scenario): Json<Scenario>,
) -> Result<Response, AppError> {
    // App-token gate (defense against random callers draining the AMap quota).
    if let Some(expected) = &state.app_token {
        let provided = headers.get("x-app-token").and_then(|v| v.to_str().ok());
        if provided != Some(expected.as_str()) {
            return Err(AppError::new(StatusCode::UNAUTHORIZED, "invalid or missing app token"));
        }
    }

    let key = cache_key(&scenario);

    // Cache hit: return the stored JSON directly.
    if let Some(body) = read_cache(&state, &key) {
        return Ok(json_response(body, true));
    }

    // Cache miss: run the (blocking) engine off the async runtime.
    let amap_key = state.amap_key.clone();
    let result = tokio::task::spawn_blocking(move || {
        pickup_op::run_analysis(&scenario, amap_key.as_deref(), &EngineConfig::default())
    })
    .await
    .map_err(|e| AppError::new(StatusCode::INTERNAL_SERVER_ERROR, format!("worker join error: {e}")))?
    .map_err(|e| AppError::new(StatusCode::BAD_GATEWAY, format!("analysis failed: {e:#}")))?;

    let body = serde_json::to_string(&result)
        .map_err(|e| AppError::new(StatusCode::INTERNAL_SERVER_ERROR, format!("serialize error: {e}")))?;

    write_cache(&state, key, body.clone());
    Ok(json_response(body, false))
}

/// Round coordinates to ~11 m so near-identical requests share a cache slot.
fn cache_key(scenario: &Scenario) -> String {
    let city = scenario
        .city
        .as_deref()
        .map(str::trim)
        .filter(|c| !c.is_empty())
        .unwrap_or("");
    format!(
        "{:.4},{:.4}|{:.4},{:.4}|{}",
        scenario.driver.lon,
        scenario.driver.lat,
        scenario.passenger.lon,
        scenario.passenger.lat,
        city,
    )
}

fn read_cache(state: &AppState, key: &str) -> Option<String> {
    let cache = state.cache.lock().ok()?;
    let entry = cache.get(key)?;
    (entry.expires > Instant::now()).then(|| entry.body.clone())
}

fn write_cache(state: &AppState, key: String, body: String) {
    if let Ok(mut cache) = state.cache.lock() {
        let now = Instant::now();
        // Opportunistically drop expired entries so the map can't grow forever.
        cache.retain(|_, e| e.expires > now);
        cache.insert(
            key,
            CacheEntry {
                expires: now + state.cache_ttl,
                body,
            },
        );
    }
}

fn json_response(body: String, cached: bool) -> Response {
    (
        StatusCode::OK,
        [
            ("content-type", "application/json"),
            ("x-cache", if cached { "HIT" } else { "MISS" }),
        ],
        body,
    )
        .into_response()
}

fn non_empty_env(name: &str) -> Option<String> {
    std::env::var(name).ok().map(|v| v.trim().to_string()).filter(|v| !v.is_empty())
}

async fn shutdown_signal() {
    let _ = tokio::signal::ctrl_c().await;
    tracing::info!("shutdown signal received");
}
