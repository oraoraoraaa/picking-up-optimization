import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:amap_map/amap_map.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:x_amap_base/x_amap_base.dart';

void main() {
  runApp(const PickupOptimizationApp());
}

class PickupOptimizationApp extends StatelessWidget {
  const PickupOptimizationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picking-Up Optimization',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7FB1D6)),
        scaffoldBackgroundColor: const Color(0xFF111827),
      ),
      debugShowCheckedModeBanner: false,
      home: const DashboardPage(),
    );
  }
}

enum UserMode { driver, passenger }

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(39.909187, 116.397451),
    zoom: 11.5,
  );
  static const AMapApiKey _amapApiKeys = AMapApiKey(
    androidKey: String.fromEnvironment('AMAP_ANDROID_KEY', defaultValue: ''),
    iosKey: String.fromEnvironment('AMAP_IOS_KEY', defaultValue: ''),
  );
  static const AMapPrivacyStatement _privacyStatement = AMapPrivacyStatement(
    hasContains: true,
    hasShow: true,
    hasAgree: true,
  );

  UserMode _mode = UserMode.driver;
  bool _modeMenuExpanded = false;
  AMapController? _mapController;
  bool _centeredOnUser = false;
  bool _locationReady = false;

  bool get _supportsAmap {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _hasConfiguredApiKey {
    final android = (_amapApiKeys.androidKey ?? '').trim();
    final ios = (_amapApiKeys.iosKey ?? '').trim();
    return android.isNotEmpty || ios.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  @override
  void reassemble() {
    super.reassemble();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _mode == UserMode.driver
        ? "Where's your passenger?"
        : "Where's your driver?";

    if (_supportsAmap) {
      AMapInitializer.init(context, apiKey: _amapApiKeys);
      AMapInitializer.updatePrivacyAgree(_privacyStatement);
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: _buildMapBackground()),
            Positioned(top: 20, right: 20, child: _buildModeSelector()),
            Positioned(
              left: 14,
              right: 14,
              bottom: 16,
              child: _buildBottomPanel(prompt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    if (_supportsAmap && _hasConfiguredApiKey) {
      return Stack(
        children: [
          AMapWidget(
            initialCameraPosition: _defaultCamera,
            trafficEnabled: true,
            scaleEnabled: false,
            compassEnabled: false,
            myLocationStyleOptions: MyLocationStyleOptions(
              true,
              circleFillColor: const Color(0x334BD5FF),
              circleStrokeColor: const Color(0xFF1D9BD1),
              circleStrokeWidth: 1,
            ),
            onMapCreated: (AMapController controller) {
              _mapController = controller;
            },
            onLocationChanged: (AMapLocation location) {
              final lat = location.latLng.latitude;
              final lng = location.latLng.longitude;
              final hasValidLocation =
                  lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
              if (!hasValidLocation || _mapController == null) {
                return;
              }

              if (!_centeredOnUser) {
                _centeredOnUser = true;
                _mapController!.moveCamera(
                  CameraUpdate.newLatLngZoom(location.latLng, 15.5),
                );
              }

              if (!_locationReady && mounted) {
                setState(() {
                  _locationReady = true;
                });
              }
            },
          ),
          if (!_locationReady)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0A1A2B),
                alignment: Alignment.center,
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.8),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Fetching current location...',
                      style: TextStyle(color: Color(0xFFE7F8FF), fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-0.8, -1),
              end: Alignment(0.8, 1),
              colors: [Color(0xFF0A1A2B), Color(0xFF11253A), Color(0xFF0B1728)],
            ),
          ),
        ),
        Positioned(top: 24, left: 16, right: 16, child: _buildAmapHintCard()),
      ],
    );
  }

  Widget _buildAmapHintCard() {
    final reason = !_supportsAmap
        ? 'AMap is available on iOS and Android only.'
        : 'Missing AMAP API key. Pass keys with --dart-define.';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_outlined, color: Color(0xFFBDEEFF), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(color: Color(0xFFE7F8FF), fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    if (_modeMenuExpanded) {
      return _glassCard(
        width: 228,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode Selection',
              style: TextStyle(
                color: Color(0xFFF4FAFF),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _modeOption(UserMode.driver, "I'm the driver"),
            const SizedBox(height: 7),
            _modeOption(UserMode.passenger, "I'm the passenger"),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _modeMenuExpanded = true),
      child: _glassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Text(
          _mode == UserMode.driver ? 'Driver Mode' : 'Passenger Mode',
          style: const TextStyle(
            color: Color(0xFFF4FAFF),
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _modeOption(UserMode value, String text) {
    final selected = _mode == value;
    return InkWell(
      onTap: () {
        setState(() {
          _mode = value;
          _modeMenuExpanded = false;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(
            0xFF4D6F92,
          ).withValues(alpha: selected ? 0.54 : 0.36),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.30 : 0.12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(color: Color(0xFFF4FAFF), fontSize: 16),
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(String prompt) {
    return _glassCard(
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pick up Optimization',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w500,
              color: Color(0xFF06243C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt,
            style: const TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
          ),
          const SizedBox(height: 8),
          _searchBar(),
          const SizedBox(height: 7),
          const Text(
            'Starting from a different location?',
            style: TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
          ),
          const SizedBox(height: 8),
          _searchBar(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                backgroundColor: const Color(
                  0xFF5FC99E,
                ).withValues(alpha: 0.94),
                foregroundColor: const Color(0xFFEFFFF8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                elevation: 0,
              ),
              child: const Text(
                'Start Route Optimizing',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF58BFB7).withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Icon(Icons.search, color: Color(0xFFE9FFF8), size: 28),
          SizedBox(width: 10),
          Text(
            'Search for a place or address',
            style: TextStyle(color: Color(0xFFE9FFF8), fontSize: 16.5),
          ),
        ],
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    double borderRadius = 24,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double? width,
  }) {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFB6EDE7).withValues(alpha: 0.72),
                const Color(0xFF83D5D2).withValues(alpha: 0.60),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
