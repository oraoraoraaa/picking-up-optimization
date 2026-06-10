import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:x_amap_base/x_amap_base.dart';

/// On-device port of the Rust core engine (`core/src/engine.rs`).
///
/// The Rust core is the reference implementation of the route-interception
/// algorithm; this service mirrors its candidate generation, scoring weights,
/// and decision rule so the same plan can be computed on phones until the
/// FFI bridge lands. Keep the constants below in sync with `EngineConfig`.
class EngineTuning {
  static const int maxCandidates = 4;
  static const double minCandidateSpacingM = 250;
  static const double minPassengerMoveM = 120;
  static const double walkReachM = 1200;
  static const double bicycleReachM = 3500;
  static const double transitReachM = 8000;
  static const double transitMinM = 2000;
  static const double minDriverSavingSecs = 60;
  static const double passengerBurdenWeight = 0.15;
  static const double bicyclePenaltyMin = 1.0;
  static const double transitPenaltyMin = 2.5;
  static const double minImprovementMin = 1.5;
}

enum MobilityMode { walking, bicycle, transit }

extension MobilityModeLabel on MobilityMode {
  String get verb {
    switch (this) {
      case MobilityMode.walking:
        return 'Walk';
      case MobilityMode.bicycle:
        return 'Ride a bicycle';
      case MobilityMode.transit:
        return 'Take transit';
    }
  }

  String get displayName {
    switch (this) {
      case MobilityMode.walking:
        return 'Walk';
      case MobilityMode.bicycle:
        return 'Bicycle';
      case MobilityMode.transit:
        return 'Transit';
    }
  }
}

class OptimizationRequest {
  const OptimizationRequest({
    required this.driver,
    required this.driverName,
    required this.passenger,
    required this.passengerName,
    required this.apiKey,
  });

  final LatLng driver;
  final String driverName;
  final LatLng passenger;
  final String passengerName;
  final String apiKey;
}

/// One displayable meeting plan, carrying everything the result page needs
/// to render it standalone (mirrors `Suggestion` in the Rust core; the
/// stay-put plan is folded in as a suggestion with `mode == null`).
class PickupSuggestion {
  const PickupSuggestion({
    required this.stayPut,
    required this.mode,
    required this.recommended,
    required this.meetingPoint,
    required this.meetingPointName,
    required this.meetingPointAddress,
    required this.driverEtaMin,
    required this.passengerEtaMin,
    required this.completionMin,
    required this.driverSavedMin,
    required this.score,
    required this.driverRoutePolyline,
    required this.passengerPathPolyline,
  });

  final bool stayPut;

  /// Null for the stay-put plan.
  final MobilityMode? mode;

  /// True on exactly one suggestion per result set.
  final bool recommended;
  final LatLng meetingPoint;
  final String meetingPointName;
  final String meetingPointAddress;
  final double driverEtaMin;
  final double passengerEtaMin;
  final double completionMin;
  final double driverSavedMin;
  final double score;

  /// Driver start -> this suggestion's meeting point.
  final List<LatLng> driverRoutePolyline;

  /// Passenger start -> meeting point (empty for stay-put).
  final List<LatLng> passengerPathPolyline;
}

class OptimizationResult {
  const OptimizationResult({
    required this.dataSource,
    required this.baselineDriverEtaMin,
    required this.suggestions,
  });

  /// "amap", "amap_with_fallback", or "fallback".
  final String dataSource;
  final double baselineDriverEtaMin;

  /// Per-mode winners plus the stay-put plan, recommended entry first and
  /// the rest ascending by score. Never empty (stay-put is always present).
  final List<PickupSuggestion> suggestions;

  PickupSuggestion get recommended => suggestions.firstWhere(
    (s) => s.recommended,
    orElse: () => suggestions.first,
  );
}

class RoutePoint {
  const RoutePoint(this.point, this.driverSecs);

  final LatLng point;
  final double driverSecs;
}

class DrivingRoute {
  const DrivingRoute(this.points, this.totalSecs);

  final List<RoutePoint> points;
  final double totalSecs;
}

class RouteCandidate {
  const RouteCandidate({
    required this.routeIndex,
    required this.point,
    required this.driverEtaMin,
    required this.passengerStraightM,
  });

  final int routeIndex;
  final LatLng point;
  final double driverEtaMin;
  final double passengerStraightM;
}

class EvaluatedOption {
  const EvaluatedOption({
    required this.routeIndex,
    required this.meetingPoint,
    required this.mode,
    required this.driverEtaMin,
    required this.passengerEtaMin,
    required this.score,
  });

  final int routeIndex;
  final LatLng meetingPoint;
  final MobilityMode mode;
  final double driverEtaMin;
  final double passengerEtaMin;
  final double score;

  double get completionMin => math.max(driverEtaMin, passengerEtaMin);
}

double haversineM(LatLng a, LatLng b) {
  const radiusM = 6371000.0;
  final dLat = _radians(b.latitude - a.latitude);
  final dLon = _radians(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_radians(a.latitude)) *
          math.cos(_radians(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * radiusM * math.asin(math.sqrt(h.toDouble()));
}

double _radians(double degrees) => degrees * math.pi / 180.0;

/// Mirrors `engine::generate_route_candidates` in the Rust core.
List<RouteCandidate> generateRouteCandidates(
  List<RoutePoint> route,
  LatLng passenger,
) {
  if (route.isEmpty) return const <RouteCandidate>[];
  final totalSecs = route.last.driverSecs;

  final eligible = <RouteCandidate>[];
  for (var i = 0; i < route.length; i++) {
    final vertex = route[i];
    final distance = haversineM(vertex.point, passenger);
    if (distance < EngineTuning.minPassengerMoveM) continue;
    if (distance > EngineTuning.transitReachM) continue;
    if (totalSecs - vertex.driverSecs < EngineTuning.minDriverSavingSecs) {
      continue;
    }
    eligible.add(
      RouteCandidate(
        routeIndex: i,
        point: vertex.point,
        driverEtaMin: vertex.driverSecs / 60.0,
        passengerStraightM: distance,
      ),
    );
  }

  final spaced = <RouteCandidate>[];
  for (final candidate in eligible) {
    final farEnough = spaced.every(
      (kept) =>
          haversineM(kept.point, candidate.point) >=
          EngineTuning.minCandidateSpacingM,
    );
    if (farEnough) spaced.add(candidate);
  }

  if (spaced.length <= EngineTuning.maxCandidates) return spaced;

  final picked = <RouteCandidate>[];
  for (var slot = 0; slot < EngineTuning.maxCandidates; slot++) {
    final index =
        slot *
        (spaced.length - 1) ~/
        math.max(EngineTuning.maxCandidates - 1, 1);
    picked.add(spaced[index]);
  }
  return picked;
}

List<MobilityMode> reachableModes(double distanceM) {
  return <MobilityMode>[
    if (distanceM <= EngineTuning.walkReachM) MobilityMode.walking,
    if (distanceM <= EngineTuning.bicycleReachM) MobilityMode.bicycle,
    if (distanceM >= EngineTuning.transitMinM &&
        distanceM <= EngineTuning.transitReachM)
      MobilityMode.transit,
  ];
}

double modePenaltyMin(MobilityMode mode) {
  switch (mode) {
    case MobilityMode.walking:
      return 0.0;
    case MobilityMode.bicycle:
      return EngineTuning.bicyclePenaltyMin;
    case MobilityMode.transit:
      return EngineTuning.transitPenaltyMin;
  }
}

/// Mirrors `engine::score_option` in the Rust core.
double scoreOption(
  double driverEtaMin,
  double passengerEtaMin,
  MobilityMode mode,
) {
  final completion = math.max(driverEtaMin, passengerEtaMin);
  return completion +
      EngineTuning.passengerBurdenWeight * passengerEtaMin +
      modePenaltyMin(mode);
}

/// Mirrors `engine::best_per_mode` in the Rust core: reduce a ranked list to
/// the best option per mode, preserving rank order.
List<EvaluatedOption> bestPerMode(List<EvaluatedOption> ranked) {
  final seen = <MobilityMode>{};
  return ranked
      .where((option) => seen.add(option.mode))
      .toList(growable: false);
}

class PickupOptimizer {
  PickupOptimizer({http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 8);
  static const double _fallbackDetourFactor = 1.35;
  static const double _fallbackDrivingKmh = 22.0;
  static const double _fallbackWalkingKmh = 4.8;
  static const double _fallbackBicycleKmh = 14.0;
  static const double _fallbackTransitKmh = 20.0;
  static const double _fallbackTransitOverheadMin = 5.0;

  final http.Client _http;
  bool _usedAmap = false;
  bool _usedFallback = false;

  Future<OptimizationResult> optimize(OptimizationRequest request) async {
    _usedAmap = false;
    _usedFallback = false;
    final key = request.apiKey.trim();

    final route =
        await _fetchDrivingRoute(key, request.driver, request.passenger) ??
        _fallbackDrivingRoute(request.driver, request.passenger);

    final baselineDriverEtaMin = route.totalSecs / 60.0;
    final candidates = generateRouteCandidates(route.points, request.passenger);

    String? citycode;
    final evaluated = <EvaluatedOption>[];
    for (final candidate in candidates) {
      for (final mode in reachableModes(candidate.passengerStraightM)) {
        if (mode == MobilityMode.transit && key.isNotEmpty) {
          citycode ??= await _fetchCitycode(key, request.passenger);
        }
        final passengerSecs =
            await _fetchPassengerSecs(
              key,
              mode,
              request.passenger,
              candidate.point,
              citycode,
            ) ??
            _fallbackPassengerSecs(mode, request.passenger, candidate.point);
        final passengerEtaMin = passengerSecs / 60.0;
        evaluated.add(
          EvaluatedOption(
            routeIndex: candidate.routeIndex,
            meetingPoint: candidate.point,
            mode: mode,
            driverEtaMin: candidate.driverEtaMin,
            passengerEtaMin: passengerEtaMin,
            score: scoreOption(candidate.driverEtaMin, passengerEtaMin, mode),
          ),
        );
      }
    }

    // Mirrors `engine::rank_options`: score, then passenger effort, then
    // driver ETA.
    evaluated.sort((a, b) {
      final byScore = a.score.compareTo(b.score);
      if (byScore != 0) return byScore;
      final byPassenger = a.passengerEtaMin.compareTo(b.passengerEtaMin);
      if (byPassenger != 0) return byPassenger;
      return a.driverEtaMin.compareTo(b.driverEtaMin);
    });

    // Mirrors `engine::decide`: a switch must clearly beat stay-put.
    final switchWins =
        evaluated.isNotEmpty &&
        evaluated.first.score <=
            baselineDriverEtaMin - EngineTuning.minImprovementMin;

    // Per-mode winners preserve rank order, so when a switch wins the
    // recommended option is exactly the first winner.
    final perMode = bestPerMode(evaluated);

    final suggestions = <PickupSuggestion>[];
    for (var i = 0; i < perMode.length; i++) {
      final option = perMode[i];
      final place = await _reverseGeocode(key, option.meetingPoint);
      suggestions.add(
        PickupSuggestion(
          stayPut: false,
          mode: option.mode,
          recommended: switchWins && i == 0,
          meetingPoint: option.meetingPoint,
          // Empty when reverse geocoding failed; the UI substitutes a
          // localized fallback label.
          meetingPointName: place.name ?? '',
          meetingPointAddress:
              place.address ?? _coordsLabel(option.meetingPoint),
          driverEtaMin: option.driverEtaMin,
          passengerEtaMin: option.passengerEtaMin,
          completionMin: option.completionMin,
          driverSavedMin: math.max(
            baselineDriverEtaMin - option.driverEtaMin,
            0,
          ),
          score: option.score,
          driverRoutePolyline: route.points
              .sublist(0, option.routeIndex + 1)
              .map((p) => p.point)
              .toList(growable: false),
          passengerPathPolyline: await _passengerPolyline(
            key,
            option.mode,
            request.passenger,
            option.meetingPoint,
          ),
        ),
      );
    }

    final stayPutPlace = await _reverseGeocode(key, request.passenger);
    suggestions.add(
      PickupSuggestion(
        stayPut: true,
        mode: null,
        recommended: !switchWins,
        meetingPoint: request.passenger,
        meetingPointName: request.passengerName,
        meetingPointAddress:
            stayPutPlace.address ?? _coordsLabel(request.passenger),
        driverEtaMin: baselineDriverEtaMin,
        passengerEtaMin: 0,
        completionMin: baselineDriverEtaMin,
        driverSavedMin: 0,
        score: baselineDriverEtaMin,
        driverRoutePolyline: route.points
            .map((p) => p.point)
            .toList(growable: false),
        passengerPathPolyline: const <LatLng>[],
      ),
    );

    // Recommended entry first, the rest ascending by score.
    suggestions.sort((a, b) {
      if (a.recommended != b.recommended) return a.recommended ? -1 : 1;
      return a.score.compareTo(b.score);
    });

    return OptimizationResult(
      dataSource: _dataSource,
      baselineDriverEtaMin: baselineDriverEtaMin,
      suggestions: suggestions,
    );
  }

  String get _dataSource {
    if (_usedAmap && !_usedFallback) return 'amap';
    if (_usedAmap) return 'amap_with_fallback';
    return 'fallback';
  }

  String _coordsLabel(LatLng point) =>
      '${point.longitude.toStringAsFixed(5)}, ${point.latitude.toStringAsFixed(5)}';

  String _lonLat(LatLng point) =>
      '${point.longitude.toStringAsFixed(6)},${point.latitude.toStringAsFixed(6)}';

  Future<Map<String, dynamic>?> _getJson(
    String path,
    Map<String, String> params,
  ) async {
    try {
      final uri = Uri.https('restapi.amap.com', path, params);
      final response = await _http.get(uri).timeout(_requestTimeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // v3 reports failure via status="0"; v4 via errcode!=0.
      if ('${data['status'] ?? '1'}' == '0') return null;
      if ((data['errcode'] is num) && (data['errcode'] as num) != 0) {
        return null;
      }
      _usedAmap = true;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<DrivingRoute?> _fetchDrivingRoute(
    String key,
    LatLng from,
    LatLng to,
  ) async {
    if (key.isEmpty) {
      _usedFallback = true;
      return null;
    }
    final data = await _getJson('/v3/direction/driving', <String, String>{
      'key': key,
      'origin': _lonLat(from),
      'destination': _lonLat(to),
      'strategy': '0',
      'extensions': 'all',
      'output': 'JSON',
    });
    if (data == null) {
      _usedFallback = true;
      return null;
    }

    final steps = _path(data, ['route', 'paths', 0, 'steps']);
    if (steps is! List || steps.isEmpty) {
      _usedFallback = true;
      return null;
    }

    final points = <RoutePoint>[];
    var elapsedSecs = 0.0;
    for (final rawStep in steps) {
      if (rawStep is! Map<String, dynamic>) continue;
      final stepSecs = _toDouble(rawStep['duration']) ?? 0;
      final vertices = _parsePolyline('${rawStep['polyline'] ?? ''}');
      if (vertices.length < 2) {
        elapsedSecs += stepSecs;
        continue;
      }

      final lengths = <double>[];
      var stepLength = 0.0;
      for (var i = 0; i + 1 < vertices.length; i++) {
        final length = haversineM(vertices[i], vertices[i + 1]);
        lengths.add(length);
        stepLength += length;
      }

      var progress = 0.0;
      for (var i = 0; i < vertices.length; i++) {
        if (i > 0) progress += lengths[i - 1];
        final isDuplicateJoint =
            i == 0 &&
            points.isNotEmpty &&
            points.last.point.latitude == vertices[i].latitude &&
            points.last.point.longitude == vertices[i].longitude;
        if (isDuplicateJoint) continue;
        final fraction = stepLength > 0 ? progress / stepLength : 0.0;
        points.add(RoutePoint(vertices[i], elapsedSecs + stepSecs * fraction));
      }
      elapsedSecs += stepSecs;
    }

    if (points.length < 2) {
      _usedFallback = true;
      return null;
    }
    points[points.length - 1] = RoutePoint(points.last.point, elapsedSecs);
    return DrivingRoute(points, elapsedSecs);
  }

  Future<double?> _fetchPassengerSecs(
    String key,
    MobilityMode mode,
    LatLng from,
    LatLng to,
    String? citycode,
  ) async {
    if (key.isEmpty) {
      _usedFallback = true;
      return null;
    }

    dynamic duration;
    switch (mode) {
      case MobilityMode.walking:
        final data = await _getJson('/v3/direction/walking', <String, String>{
          'key': key,
          'origin': _lonLat(from),
          'destination': _lonLat(to),
          'output': 'JSON',
        });
        duration = data == null
            ? null
            : _path(data, ['route', 'paths', 0, 'duration']);
      case MobilityMode.bicycle:
        final data = await _getJson('/v4/direction/bicycling', <String, String>{
          'key': key,
          'origin': _lonLat(from),
          'destination': _lonLat(to),
        });
        duration = data == null
            ? null
            : _path(data, ['data', 'paths', 0, 'duration']);
      case MobilityMode.transit:
        if (citycode == null) {
          _usedFallback = true;
          return null;
        }
        final data =
            await _getJson('/v3/direction/transit/integrated', <String, String>{
              'key': key,
              'origin': _lonLat(from),
              'destination': _lonLat(to),
              'city': citycode,
              'output': 'JSON',
            });
        duration = data == null
            ? null
            : _path(data, ['route', 'transits', 0, 'duration']);
    }

    final secs = _toDouble(duration);
    if (secs == null) _usedFallback = true;
    return secs;
  }

  /// Passenger start -> meeting point path; walking and bicycling have real
  /// path APIs, transit falls back to a straight line (mirrors the core).
  Future<List<LatLng>> _passengerPolyline(
    String key,
    MobilityMode mode,
    LatLng from,
    LatLng to,
  ) async {
    List<LatLng>? polyline;
    switch (mode) {
      case MobilityMode.walking:
        polyline = await _fetchPathPolyline(
          key,
          '/v3/direction/walking',
          ['route', 'paths', 0, 'steps'],
          from,
          to,
        );
      case MobilityMode.bicycle:
        polyline = await _fetchPathPolyline(
          key,
          '/v4/direction/bicycling',
          ['data', 'paths', 0, 'steps'],
          from,
          to,
        );
      case MobilityMode.transit:
        polyline = null;
    }
    return polyline ?? <LatLng>[from, to];
  }

  Future<List<LatLng>?> _fetchPathPolyline(
    String key,
    String apiPath,
    List<Object> stepsPath,
    LatLng from,
    LatLng to,
  ) async {
    if (key.isEmpty) return null;
    final data = await _getJson(apiPath, <String, String>{
      'key': key,
      'origin': _lonLat(from),
      'destination': _lonLat(to),
      'output': 'JSON',
    });
    if (data == null) return null;

    final steps = _path(data, stepsPath);
    if (steps is! List) return null;
    final polyline = <LatLng>[];
    for (final step in steps) {
      if (step is! Map<String, dynamic>) continue;
      for (final vertex in _parsePolyline('${step['polyline'] ?? ''}')) {
        if (polyline.isEmpty ||
            polyline.last.latitude != vertex.latitude ||
            polyline.last.longitude != vertex.longitude) {
          polyline.add(vertex);
        }
      }
    }
    return polyline.length >= 2 ? polyline : null;
  }

  Future<String?> _fetchCitycode(String key, LatLng location) async {
    final data = await _getJson('/v3/geocode/regeo', <String, String>{
      'key': key,
      'location': _lonLat(location),
      'output': 'JSON',
    });
    final citycode = data == null
        ? null
        : _path(data, ['regeocode', 'addressComponent', 'citycode']);
    return citycode is String && citycode.isNotEmpty ? citycode : null;
  }

  /// Resolve a human-friendly place name (nearest POI preferred) and a
  /// formatted address for a coordinate.
  Future<({String? name, String? address})> _reverseGeocode(
    String key,
    LatLng location,
  ) async {
    if (key.isEmpty) return (name: null, address: null);
    final data = await _getJson('/v3/geocode/regeo', <String, String>{
      'key': key,
      'location': _lonLat(location),
      'extensions': 'all',
      'radius': '300',
      'output': 'JSON',
    });
    if (data == null) return (name: null, address: null);

    String? name;
    final pois = _path(data, ['regeocode', 'pois']);
    if (pois is List && pois.isNotEmpty) {
      final first = pois.first;
      if (first is Map<String, dynamic>) {
        final poiName = '${first['name'] ?? ''}'.trim();
        if (poiName.isNotEmpty) name = poiName;
      }
    }

    String? address;
    final formatted = _path(data, ['regeocode', 'formatted_address']);
    if (formatted is String && formatted.trim().isNotEmpty) {
      address = formatted.trim();
    }
    return (name: name ?? address, address: address);
  }

  DrivingRoute _fallbackDrivingRoute(LatLng from, LatLng to) {
    _usedFallback = true;
    const vertices = 32;
    final roadM = haversineM(from, to) * _fallbackDetourFactor;
    final totalSecs = math.max(
      roadM / 1000.0 / _fallbackDrivingKmh * 3600.0,
      60.0,
    );

    final points = List<RoutePoint>.generate(vertices, (i) {
      final t = i / (vertices - 1);
      return RoutePoint(
        LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
        totalSecs * t,
      );
    });
    return DrivingRoute(points, totalSecs);
  }

  double _fallbackPassengerSecs(MobilityMode mode, LatLng from, LatLng to) {
    _usedFallback = true;
    final km = haversineM(from, to) / 1000.0;
    double mins;
    switch (mode) {
      case MobilityMode.walking:
        mins = km / _fallbackWalkingKmh * 60.0;
      case MobilityMode.bicycle:
        mins = km / _fallbackBicycleKmh * 60.0;
      case MobilityMode.transit:
        mins = km / _fallbackTransitKmh * 60.0 + _fallbackTransitOverheadMin;
    }
    return math.max(mins, 1.0) * 60.0;
  }

  List<LatLng> _parsePolyline(String raw) {
    final points = <LatLng>[];
    for (final pair in raw.split(';')) {
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final lon = double.tryParse(parts[0].trim());
      final lat = double.tryParse(parts[1].trim());
      if (lon == null || lat == null) continue;
      points.add(LatLng(lat, lon));
    }
    return points;
  }

  dynamic _path(dynamic node, List<Object> keys) {
    dynamic current = node;
    for (final key in keys) {
      if (key is int) {
        if (current is List && key < current.length) {
          current = current[key];
        } else {
          return null;
        }
      } else if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
