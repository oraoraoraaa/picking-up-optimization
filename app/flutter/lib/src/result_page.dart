import 'dart:math' as math;

import 'package:amap_map/amap_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'amap_config.dart';
import 'pickup_optimizer.dart';

/// Result screen implementing `resource/images/design/result_v1.png`:
/// route preview map, FASTEST summary card, meeting-up location card,
/// and Share / Open in Maps actions.
class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.request, this.runOptimization});

  final OptimizationRequest request;

  /// Test seam; defaults to [PickupOptimizer.optimize].
  final Future<OptimizationResult> Function(OptimizationRequest)?
      runOptimization;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late Future<OptimizationResult> _future;

  static const Color _pageBackground = Color(0xFF111827);
  static const Color _cardGreenTop = Color(0xFF6FD2A8);
  static const Color _cardGreenBottom = Color(0xFF43AE85);
  static const Color _cardPink = Color(0xFFF0C5CE);
  static const Color _sharePurple = Color(0xFFB89AE8);
  static const Color _openBlue = Color(0xFF7FB3E8);
  static const Color _driverRouteColor = Color(0xFF5FA8FF);
  static const Color _passengerPathColor = Color(0xFF53E0B4);

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<OptimizationResult> _run() {
    final runner = widget.runOptimization;
    if (runner != null) return runner(widget.request);
    return PickupOptimizer().optimize(widget.request);
  }

  void _retry() {
    setState(() {
      _future = _run();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: FutureBuilder<OptimizationResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildResult(snapshot.data!);
            }
            if (snapshot.hasError) {
              return _buildError('${snapshot.error}');
            }
            return _buildLoading();
          },
        ),
      ),
    );
  }

  Widget _buildHeader({String? badge}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFFE7F8FF),
                size: 21,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Optimization Result',
            style: TextStyle(
              color: Color(0xFFE7F8FF),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Color(0xFFBDEEFF),
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Optimizing your pickup...',
                style: TextStyle(color: Color(0xFFE7F8FF), fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                'Checking traffic and meeting points along the route',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  color: Color(0xFFBDEEFF),
                  size: 38,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Optimization failed',
                  style: TextStyle(
                    color: Color(0xFFE7F8FF),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(OptimizationResult result) {
    final badge = switch (result.dataSource) {
      'amap' => 'Live traffic',
      'amap_with_fallback' => 'Live + estimates',
      _ => 'Estimates only',
    };

    return Column(
      children: [
        _buildHeader(badge: badge),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMapCard(result),
                const SizedBox(height: 14),
                _buildFastestCard(result),
                const SizedBox(height: 14),
                _buildMeetingLocationCard(result),
                const SizedBox(height: 18),
                _buildActions(result),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Map card ---------------------------------------------------------

  Widget _buildMapCard(OptimizationResult result) {
    final height = math.max(MediaQuery.of(context).size.height * 0.38, 230.0);
    final best = result.best;

    final driverChip = _mapChip(
      label: 'Drive ${best.driverEtaMin.ceil()} min',
      background: Colors.white.withValues(alpha: 0.92),
      foreground: const Color(0xFF14324F),
    );
    final passengerChip = _mapChip(
      label: best.stayPut
          ? 'Passenger stays put'
          : '${best.mode!.verb} ${best.passengerEtaMin.ceil()} min · Suggested',
      background: const Color(0xE0337FD6),
      foreground: Colors.white,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: _buildMapLayer(result)),
            Positioned(
              left: 12,
              top: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  passengerChip,
                  const SizedBox(height: 8),
                  driverChip,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapChip({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMapLayer(OptimizationResult result) {
    if (supportsAmapPlatform && hasConfiguredMapKey) {
      return _buildAmapLayer(result);
    }
    return CustomPaint(
      painter: _RoutePreviewPainter(
        driverRoute: result.driverRoutePolyline,
        passengerPath: result.passengerPathPolyline,
        driverColor: _driverRouteColor,
        passengerColor: _passengerPathColor,
      ),
    );
  }

  Widget _buildAmapLayer(OptimizationResult result) {
    final request = widget.request;
    final best = result.best;

    final polylines = <Polyline>{
      if (result.driverRoutePolyline.length >= 2)
        Polyline(
          points: result.driverRoutePolyline,
          color: _driverRouteColor,
          width: 9,
          joinType: JoinType.round,
          capType: CapType.round,
        ),
      if (result.passengerPathPolyline.length >= 2)
        Polyline(
          points: result.passengerPathPolyline,
          color: _passengerPathColor,
          width: 7,
          dashLineType: DashLineType.square,
          joinType: JoinType.round,
          capType: CapType.round,
        ),
    };

    final markers = <Marker>{
      Marker(
        position: request.driver,
        infoWindow: InfoWindow(title: 'Driver: ${request.driverName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        position: request.passenger,
        infoWindow: InfoWindow(title: 'Passenger: ${request.passengerName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      Marker(
        position: best.meetingPoint,
        infoWindow: InfoWindow(title: 'Meet here: ${best.meetingPointName}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };

    final allPoints = <LatLng>[
      request.driver,
      request.passenger,
      best.meetingPoint,
      ...result.driverRoutePolyline,
      ...result.passengerPathPolyline,
    ];

    return AMapWidget(
      initialCameraPosition: CameraPosition(
        target: best.meetingPoint,
        zoom: 13,
      ),
      trafficEnabled: true,
      scaleEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      polylines: polylines,
      markers: markers,
      onMapCreated: (AMapController controller) {
        controller.moveCamera(
          CameraUpdate.newLatLngBounds(_boundsFor(allPoints), 56),
        );
      },
    );
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  // --- FASTEST card -------------------------------------------------------

  Widget _buildFastestCard(OptimizationResult result) {
    final best = result.best;
    final passengerLine = best.stayPut
        ? 'Passenger: Stay at the pickup point'
        : 'Passenger: ${best.mode!.verb} ${best.passengerEtaMin.ceil()} mins '
            'to ${best.meetingPointName}';
    final driverLine = best.stayPut
        ? 'Driver: Arrive in ${best.driverEtaMin.ceil()} mins — the direct '
            'route is already fastest'
        : 'Driver: Save ${best.driverSavedMin.round()} mins driving time';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_cardGreenTop, _cardGreenBottom],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FASTEST',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passengerLine,
            style: const TextStyle(
              color: Color(0xFF0E3D2C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            driverLine,
            style: const TextStyle(
              color: Color(0xFF0E3D2C),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Meeting location card ----------------------------------------------

  Widget _buildMeetingLocationCard(OptimizationResult result) {
    final best = result.best;
    final showAddress = best.meetingPointAddress.trim().isNotEmpty &&
        best.meetingPointAddress != best.meetingPointName;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: _cardPink,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MEETING UP LOCATION:',
            style: TextStyle(
              color: Color(0xFF7C3A4C),
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  best.meetingPointName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF3A2A35),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showAddress) ...[
                  const SizedBox(height: 3),
                  Text(
                    best.meetingPointAddress,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF3A2A35).withValues(alpha: 0.7),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Actions --------------------------------------------------------------

  Widget _buildActions(OptimizationResult result) {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            label: 'Share',
            color: _sharePurple,
            onPressed: () => _shareSummary(result),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            label: 'Open in Maps',
            color: _openBlue,
            onPressed: () => _openInMaps(result),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _mapsUrl(OptimizationResult result) {
    final point = result.best.meetingPoint;
    final name = Uri.encodeComponent(result.best.meetingPointName);
    return 'https://uri.amap.com/marker?position=${point.longitude},'
        '${point.latitude}&name=$name&src=pickup-op';
  }

  Future<void> _shareSummary(OptimizationResult result) async {
    final best = result.best;
    final lines = <String>[
      'Pickup plan — Picking-Up Optimization',
      'Meet at: ${best.meetingPointName}',
      if (best.meetingPointAddress != best.meetingPointName)
        'Address: ${best.meetingPointAddress}',
      if (!best.stayPut && best.mode != null)
        'Passenger: ${best.mode!.verb.toLowerCase()} '
            '~${best.passengerEtaMin.ceil()} min',
      'Driver: arrives in ~${best.driverEtaMin.ceil()} min'
          '${best.stayPut ? '' : ', saves ~${best.driverSavedMin.round()} min'}',
      _mapsUrl(result),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pickup plan copied — paste it anywhere to share'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openInMaps(OptimizationResult result) async {
    final ok = await launchUrl(
      Uri.parse(_mapsUrl(result)),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the map application'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// Schematic route preview used where the AMap SDK is unavailable
/// (desktop/web or missing keys): real polyline geometry projected into the
/// card with a map-like grid backdrop.
class _RoutePreviewPainter extends CustomPainter {
  _RoutePreviewPainter({
    required this.driverRoute,
    required this.passengerPath,
    required this.driverColor,
    required this.passengerColor,
  });

  final List<LatLng> driverRoute;
  final List<LatLng> passengerPath;
  final Color driverColor;
  final Color passengerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF14253B), Color(0xFF0E1C2E)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, background);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const gridStep = 34.0;
    for (var x = 0.0; x < size.width; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final all = <LatLng>[...driverRoute, ...passengerPath];
    if (all.length < 2) return;

    final project = _projector(all, size);

    if (driverRoute.length >= 2) {
      final path = _toPath(driverRoute, project);
      canvas.drawPath(
        path,
        Paint()
          ..color = driverColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (passengerPath.length >= 2) {
      final path = _toPath(passengerPath, project);
      _drawDashedPath(
        canvas,
        path,
        Paint()
          ..color = passengerColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
        dash: 9,
        gap: 7,
      );
    }

    if (driverRoute.isNotEmpty) {
      _drawEndpoint(canvas, project(driverRoute.first), driverColor);
    }
    if (passengerPath.isNotEmpty) {
      _drawEndpoint(canvas, project(passengerPath.first), passengerColor);
    }
    final meeting = driverRoute.isNotEmpty
        ? project(driverRoute.last)
        : project(passengerPath.last);
    canvas.drawCircle(
      meeting,
      9,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
    canvas.drawCircle(meeting, 5.5, Paint()..color = const Color(0xFF43AE85));
  }

  Offset Function(LatLng) _projector(List<LatLng> points, Size size) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLon = points.first.longitude;
    var maxLon = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLon = math.min(minLon, p.longitude);
      maxLon = math.max(maxLon, p.longitude);
    }

    final midLat = (minLat + maxLat) / 2;
    final lonScale = math.cos(midLat * math.pi / 180.0);
    final spanX = math.max((maxLon - minLon) * lonScale, 1e-6);
    final spanY = math.max(maxLat - minLat, 1e-6);

    const padding = 30.0;
    final scale = math.min(
      (size.width - padding * 2) / spanX,
      (size.height - padding * 2) / spanY,
    );
    final offsetX = (size.width - spanX * scale) / 2;
    final offsetY = (size.height - spanY * scale) / 2;

    return (LatLng p) => Offset(
          offsetX + (p.longitude - minLon) * lonScale * scale,
          offsetY + (maxLat - p.latitude) * scale,
        );
  }

  Path _toPath(List<LatLng> points, Offset Function(LatLng) project) {
    final path = Path();
    final first = project(points.first);
    path.moveTo(first.dx, first.dy);
    for (final point in points.skip(1)) {
      final offset = project(point);
      path.lineTo(offset.dx, offset.dy);
    }
    return path;
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  void _drawEndpoint(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      7.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, 4.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RoutePreviewPainter oldDelegate) {
    return oldDelegate.driverRoute != driverRoute ||
        oldDelegate.passengerPath != passengerPath;
  }
}
