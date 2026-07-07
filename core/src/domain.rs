use serde::{Deserialize, Serialize};

/// A WGS-ish AMap coordinate (GCJ-02), longitude first to match AMap conventions.
#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize)]
pub struct GeoPoint {
    pub lon: f64,
    pub lat: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NamedPoint {
    #[serde(default)]
    pub name: String,
    pub lon: f64,
    pub lat: f64,
}

impl NamedPoint {
    pub fn point(&self) -> GeoPoint {
        GeoPoint {
            lon: self.lon,
            lat: self.lat,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MobilityMode {
    Walking,
    Bicycle,
    Transit,
}

impl MobilityMode {
    pub fn label(&self) -> &'static str {
        match self {
            MobilityMode::Walking => "walk",
            MobilityMode::Bicycle => "ride a bicycle",
            MobilityMode::Transit => "take transit",
        }
    }
}

/// One vertex of the driver's inbound route with cumulative travel estimates
/// measured from the driver's start.
#[derive(Clone, Copy, Debug)]
pub struct RoutePoint {
    pub point: GeoPoint,
    pub driver_secs: f64,
    pub meters_from_start: f64,
}

/// A meeting-point candidate generated on the driver's route.
#[derive(Clone, Copy, Debug)]
pub struct Candidate {
    /// Index of the vertex in the driver route polyline.
    pub route_index: usize,
    pub point: GeoPoint,
    pub driver_eta_min: f64,
    /// Straight-line distance from the passenger start, used for mode gating.
    pub passenger_straight_m: f64,
}

/// A candidate-mode combination after scoring.
#[derive(Clone, Debug, Serialize)]
pub struct EvaluatedOption {
    pub meeting_point: GeoPoint,
    pub route_index: usize,
    pub mode: MobilityMode,
    pub driver_eta_min: f64,
    pub passenger_eta_min: f64,
    pub completion_min: f64,
    pub score: f64,
}

/// One displayable meeting plan: the best evaluated option for one passenger
/// mode, carrying everything the UI needs to render it standalone.
#[derive(Clone, Debug, Serialize)]
pub struct Suggestion {
    pub mode: MobilityMode,
    /// True on the single suggestion that beats stay-put per the engine's
    /// decision rule (at most one across the whole set).
    pub recommended: bool,
    pub meeting_point: GeoPoint,
    /// Human-friendly meeting-point name (nearest POI); empty when unresolved.
    #[serde(default)]
    pub meeting_point_name: String,
    /// Formatted meeting-point address; empty when unresolved.
    #[serde(default)]
    pub meeting_point_address: String,
    pub driver_eta_min: f64,
    pub passenger_eta_min: f64,
    pub completion_min: f64,
    pub driver_saved_min: f64,
    pub score: f64,
    pub rationale: String,
    /// Driver start -> this suggestion's meeting point.
    pub driver_route_polyline: Vec<GeoPoint>,
    /// Passenger start -> this suggestion's meeting point.
    pub passenger_path_polyline: Vec<GeoPoint>,
}

/// The "do nothing" plan: driver goes all the way to the passenger.
#[derive(Clone, Debug, Serialize)]
pub struct StayPutSuggestion {
    /// True when no alternative clears the improvement bar.
    pub recommended: bool,
    pub driver_eta_min: f64,
    pub completion_min: f64,
    pub rationale: String,
    /// Passenger-location name (the original pickup point); empty when unresolved.
    #[serde(default)]
    pub meeting_point_name: String,
    /// Passenger-location formatted address; empty when unresolved.
    #[serde(default)]
    pub meeting_point_address: String,
    /// Driver start -> passenger (full route).
    pub driver_route_polyline: Vec<GeoPoint>,
}

#[derive(Clone, Debug, Serialize)]
pub struct RecommendationSet {
    pub generated_at: String,
    pub data_source: String,
    pub passenger_start: NamedPoint,
    pub driver_start: NamedPoint,
    pub stay_put: StayPutSuggestion,
    /// Per-mode winners in rank order (best overall first); may be empty when
    /// no candidate is reachable.
    pub suggestions: Vec<Suggestion>,
}

/// CLI / bridge input contract.
#[derive(Clone, Debug, Deserialize)]
pub struct Scenario {
    pub driver: NamedPoint,
    pub passenger: NamedPoint,
    /// City name or citycode used for transit planning (AMap v3 requirement).
    #[serde(default)]
    pub city: Option<String>,
}
