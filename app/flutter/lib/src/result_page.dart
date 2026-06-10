import 'dart:math' as math;

import 'package:amap_map/amap_map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'amap_config.dart';
import 'app_settings.dart';
import 'l10n.dart';
import 'map_launcher.dart';
import 'pickup_optimizer.dart';

/// Result screen (v2): the design of `resource/images/design/result_v1.png`
/// extended with a tappable suggestion list — one entry per passenger mode
/// (walk / bicycle / transit) plus the stay-put plan. Selecting a suggestion
/// drives the route preview map, the summary cards, and the actions.
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
  int _selectedIndex = 0;
  AMapController? _mapController;

  static const Color _pageBackground = Color(0xFF111827);
  static const Color _cardGreenTop = Color(0xFF6FD2A8);
  static const Color _cardGreenBottom = Color(0xFF43AE85);
  static const Color _cardSlateTop = Color(0xFF5C7693);
  static const Color _cardSlateBottom = Color(0xFF435A75);
  static const Color _cardPink = Color(0xFFF0C5CE);
  static const Color _sharePurple = Color(0xFFB89AE8);
  static const Color _openBlue = Color(0xFF7FB3E8);
  static const Color _driverRouteColor = Color(0xFF5FA8FF);
  static const Color _passengerPathColor = Color(0xFF53E0B4);
  static const Color _selectionTeal = Color(0xFF58BFB7);

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
      _selectedIndex = 0;
      _future = _run();
    });
  }

  void _selectSuggestion(OptimizationResult result, int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
    });
    final controller = _mapController;
    if (controller != null) {
      controller.moveCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFor(_focusPoints(result.suggestions[index])),
          56,
        ),
      );
    }
  }

  List<LatLng> _focusPoints(PickupSuggestion suggestion) {
    return <LatLng>[
      widget.request.driver,
      widget.request.passenger,
      suggestion.meetingPoint,
      ...suggestion.driverRoutePolyline,
      ...suggestion.passengerPathPolyline,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark page background -> light status bar icons.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
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
      ),
    );
  }

  /// Localized display name with a fallback when reverse geocoding failed.
  String _displayName(S s, PickupSuggestion suggestion) {
    final name = suggestion.meetingPointName.trim();
    return name.isEmpty ? s.fallbackMeetingName : name;
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
          Text(
            S.of(context).optimizationResult,
            style: const TextStyle(
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
    final s = S.of(context);
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
              Text(
                s.optimizingTitle,
                style: const TextStyle(color: Color(0xFFE7F8FF), fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                s.optimizingSubtitle,
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
                Text(
                  S.of(context).optimizationFailed,
                  style: const TextStyle(
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
                  child: Text(S.of(context).tryAgain),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(OptimizationResult result) {
    final s = S.of(context);
    final badge = switch (result.dataSource) {
      'amap' => s.badgeLiveTraffic,
      'amap_with_fallback' => s.badgeLiveEstimates,
      _ => s.badgeEstimatesOnly,
    };
    final index = _selectedIndex.clamp(0, result.suggestions.length - 1);
    final selected = result.suggestions[index];

    return Column(
      children: [
        _buildHeader(badge: badge),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMapCard(selected),
                const SizedBox(height: 14),
                _buildSuggestionList(result, index),
                const SizedBox(height: 14),
                // Cross-fade the detail cards when the selection changes so
                // switching suggestions feels continuous.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final slide = Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        ).animate(animation);
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(position: slide, child: child),
                        );
                      },
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                  child: Column(
                    key: ValueKey<int>(index),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildDetailCard(selected),
                      const SizedBox(height: 14),
                      _buildMeetingLocationCard(selected),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildActions(selected),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Map card -------------------------------------------------------------

  Widget _buildMapCard(PickupSuggestion selected) {
    final s = S.of(context);
    final height = math.max(MediaQuery.of(context).size.height * 0.32, 210.0);

    final driverChip = _mapChip(
      label: s.chipDrive(selected.driverEtaMin.ceil()),
      background: Colors.white.withValues(alpha: 0.92),
      foreground: const Color(0xFF14324F),
    );
    final passengerChip = _mapChip(
      label: selected.stayPut
          ? s.chipStaysPut
          : s.chipPassengerGo(
              selected.mode!,
              selected.passengerEtaMin.ceil(),
              suggested: selected.recommended,
            ),
      background: const Color(0xE0337FD6),
      foreground: Colors.white,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: _buildMapLayer(selected)),
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

  Widget _buildMapLayer(PickupSuggestion selected) {
    if (supportsAmapPlatform && hasConfiguredMapKey) {
      return _buildAmapLayer(selected);
    }
    // RepaintBoundary keeps page scrolling from re-rasterizing the preview.
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RoutePreviewPainter(
          driverRoute: selected.driverRoutePolyline,
          passengerPath: selected.passengerPathPolyline,
          driverColor: _driverRouteColor,
          passengerColor: _passengerPathColor,
        ),
      ),
    );
  }

  Widget _buildAmapLayer(PickupSuggestion selected) {
    final request = widget.request;

    final polylines = <Polyline>{
      if (selected.driverRoutePolyline.length >= 2)
        Polyline(
          points: selected.driverRoutePolyline,
          color: _driverRouteColor,
          width: 9,
          joinType: JoinType.round,
          capType: CapType.round,
        ),
      if (selected.passengerPathPolyline.length >= 2)
        Polyline(
          points: selected.passengerPathPolyline,
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
        infoWindow: InfoWindow(
          title: S.of(context).markerDriver(request.driverName),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        position: request.passenger,
        infoWindow: InfoWindow(
          title: S.of(context).markerPassenger(request.passengerName),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
      if (!selected.stayPut)
        Marker(
          position: selected.meetingPoint,
          infoWindow: InfoWindow(
            title: S
                .of(context)
                .markerMeetHere(_displayName(S.of(context), selected)),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
    };

    return AMapWidget(
      initialCameraPosition: CameraPosition(
        target: selected.meetingPoint,
        zoom: 13,
      ),
      trafficEnabled: true,
      scaleEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      polylines: polylines,
      markers: markers,
      // The map sits inside a scroll view; claim drags eagerly so panning
      // moves the map instead of scrolling the page.
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
      onMapCreated: (AMapController controller) {
        _mapController = controller;
        controller.moveCamera(
          CameraUpdate.newLatLngBounds(_boundsFor(_focusPoints(selected)), 56),
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

  // --- Suggestion list --------------------------------------------------------

  IconData _suggestionIcon(PickupSuggestion suggestion) {
    if (suggestion.stayPut) return Icons.hail_rounded;
    switch (suggestion.mode!) {
      case MobilityMode.walking:
        return Icons.directions_walk_rounded;
      case MobilityMode.bicycle:
        return Icons.directions_bike_rounded;
      case MobilityMode.transit:
        return Icons.directions_transit_rounded;
    }
  }

  Widget _buildSuggestionList(OptimizationResult result, int selectedIndex) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            S.of(context).suggestionsLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        for (var i = 0; i < result.suggestions.length; i++) ...[
          _suggestionTile(result, i, i == selectedIndex),
          if (i + 1 < result.suggestions.length) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _suggestionTile(
    OptimizationResult result,
    int index,
    bool isSelected,
  ) {
    final s = S.of(context);
    final suggestion = result.suggestions[index];
    final title = suggestion.stayPut
        ? s.stayPutTile
        : s.tileTitle(suggestion.mode!, suggestion.passengerEtaMin.ceil());
    final subtitle = suggestion.stayPut
        ? s.stayPutSubtitle
        : s.meetAt(_displayName(s, suggestion));

    return InkWell(
      onTap: () => _selectSuggestion(result, index),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? _selectionTeal.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? _selectionTeal.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.14),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isSelected ? 0.22 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _suggestionIcon(suggestion),
                color: const Color(0xFFD9FFF4),
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEFFFF8),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (suggestion.recommended) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _cardGreenBottom,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            s.cardFastest,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  s.minutesShort(suggestion.completionMin.ceil()),
                  style: const TextStyle(
                    color: Color(0xFFEFFFF8),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  suggestion.stayPut
                      ? s.baselineTag
                      : s.driverSavesTag(suggestion.driverSavedMin.round()),
                  style: TextStyle(
                    color: suggestion.stayPut
                        ? Colors.white.withValues(alpha: 0.55)
                        : const Color(0xFF8FF3CB),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Detail card ------------------------------------------------------------

  Widget _buildDetailCard(PickupSuggestion selected) {
    final s = S.of(context);
    final title = selected.recommended
        ? s.cardFastest
        : selected.stayPut
        ? s.cardStayPut
        : s.cardAlternative;
    final gradientColors = selected.recommended
        ? const [_cardGreenTop, _cardGreenBottom]
        : const [_cardSlateTop, _cardSlateBottom];
    final textColor = selected.recommended
        ? const Color(0xFF0E3D2C)
        : const Color(0xFFEAF3FF);

    final passengerLine = selected.stayPut
        ? s.passengerStayLine
        : s.passengerGoLine(
            selected.mode!,
            selected.passengerEtaMin.ceil(),
            _displayName(s, selected),
          );
    final driverLine = selected.stayPut
        ? s.driverArriveLine(
            selected.driverEtaMin.ceil(),
            directFastest: selected.recommended,
          )
        : s.driverSaveLine(selected.driverSavedMin.round());

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors,
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passengerLine,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            driverLine,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // --- Meeting location card ----------------------------------------------

  Widget _buildMeetingLocationCard(PickupSuggestion selected) {
    final showAddress =
        selected.meetingPointAddress.trim().isNotEmpty &&
        selected.meetingPointAddress != selected.meetingPointName;

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
          Text(
            S.of(context).meetingUpLocation,
            style: const TextStyle(
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
                  _displayName(S.of(context), selected),
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
                    selected.meetingPointAddress,
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

  Widget _buildActions(PickupSuggestion selected) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            label: s.share,
            color: _sharePurple,
            onPressed: () => _shareSummary(selected),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionButton(
            label: s.openInMaps,
            color: _openBlue,
            onPressed: () => _openInMaps(selected),
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

  Future<void> _shareSummary(PickupSuggestion selected) async {
    final s = S.of(context);
    final name = _displayName(s, selected);
    final lines = <String>[
      s.shareTitle,
      s.shareMeetAt(name),
      if (selected.meetingPointAddress != name)
        s.shareAddress(selected.meetingPointAddress),
      if (!selected.stayPut && selected.mode != null)
        s.sharePassenger(selected.mode!, selected.passengerEtaMin.ceil()),
      s.shareDriver(
        selected.driverEtaMin.ceil(),
        savedMins: selected.stayPut ? null : selected.driverSavedMin.round(),
      ),
      // The web link works for any recipient regardless of installed apps.
      webMarkerUrl(selected.meetingPoint, name),
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.planCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Open the meeting point in the user's preferred map application
  /// (Settings > Default map app), falling back to the web marker page.
  Future<void> _openInMaps(PickupSuggestion selected) async {
    final s = S.of(context);
    final mapApp =
        AppSettingsScope.maybeOf(context)?.mapApp ?? MapAppChoice.amap;
    final ok = await openInMapApp(
      mapApp,
      selected.meetingPoint,
      _displayName(s, selected),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.cannotOpenMapApp),
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
