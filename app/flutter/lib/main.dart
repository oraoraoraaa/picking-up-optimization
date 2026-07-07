import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:amap_map/amap_map.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:x_amap_base/x_amap_base.dart';

import 'src/amap_config.dart';
import 'src/app_settings.dart';
import 'src/debug_log.dart';
import 'src/l10n.dart';
import 'src/map_launcher.dart';
import 'src/pickup_optimizer.dart';
import 'src/result_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(PickupOptimizationApp(settings: settings));
}

class PickupOptimizationApp extends StatelessWidget {
  const PickupOptimizationApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? child) {
          return MaterialApp(
            title: 'Picking-Up Optimization',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF7FB1D6),
              ),
              scaffoldBackgroundColor: const Color(0xFF111827),
            ),
            debugShowCheckedModeBanner: false,
            home: const DashboardPage(),
          );
        },
      ),
    );
  }
}

enum UserMode { driver, passenger }

enum _SearchField { pickup, start }

enum _SearchErrorKind { missingKey, failed }

class _PoiSuggestion {
  const _PoiSuggestion({
    required this.id,
    required this.name,
    required this.address,
    required this.latLng,
    required this.district,
  });

  final String id;
  final String name;
  final String address;
  final LatLng latLng;
  final String district;

  String get subtitle {
    if (address.trim().isNotEmpty) return address;
    return district;
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Duration _uiAnimDuration = Duration(milliseconds: 240);
  static const Duration _uiAnimFastDuration = Duration(milliseconds: 160);

  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(39.909187, 116.397451),
    zoom: 11.5,
  );
  static bool _amapInitialized = false;

  UserMode _mode = UserMode.driver;
  bool _modeMenuExpanded = false;
  bool _settingsExpanded = false;
  bool _trafficEnabled = true;
  AMapController? _mapController;
  bool _centeredOnUser = false;
  bool _locationReady = false;
  LatLng? _latestUserLocation;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _startFocusNode = FocusNode();
  _SearchField? _activeSearchField;
  bool _isSearching = false;
  // Stored as a kind (not a string) so the message follows language changes.
  _SearchErrorKind? _searchError;
  List<_PoiSuggestion> _suggestions = const <_PoiSuggestion>[];
  _PoiSuggestion? _pickupSelection;
  _PoiSuggestion? _startSelection;
  int _searchRequestToken = 0;
  Timer? _searchDebounce;
  Set<Marker> _selectedMarkers = <Marker>{};

  // Key/platform configuration is shared with the result page via
  // src/amap_config.dart.
  bool get _supportsAmap => supportsAmapPlatform;

  bool get _hasConfiguredApiKey => hasConfiguredMapKey;

  String get _effectiveSearchKey => effectiveAmapWebKey;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = _SearchField.pickup;
        });
      }
    });
    _startFocusNode.addListener(() {
      if (_startFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = _SearchField.start;
        });
      }
    });
    AppDebugLog.log(
      'Dashboard loaded. AMap support=${_supportsAmap ? 'yes' : 'no'}, map key configured=${_hasConfiguredApiKey ? 'yes' : 'no'}.',
    );
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
  void dispose() {
    _searchDebounce?.cancel();
    _pickupController.dispose();
    _startController.dispose();
    _pickupFocusNode.dispose();
    _startFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final prompt = _mode == UserMode.driver
        ? s.promptDriver
        : s.promptPassenger;

    if (_supportsAmap && !_amapInitialized) {
      AMapInitializer.init(context, apiKey: amapApiKeys);
      AMapInitializer.updatePrivacyAgree(amapPrivacyStatement);
      _amapInitialized = true;
    }

    final mapActive = _supportsAmap && _hasConfiguredApiKey;
    // The map runs edge-to-edge; floating widgets respect the safe insets
    // themselves so no letterboxing bars appear above/below the map.
    final safe = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Light map under a transparent status bar -> dark status bar icons.
      value: mapActive && _locationReady
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              Positioned.fill(child: _buildMapBackground()),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: safe.top + 46,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.22),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: safe.top + 10,
                right: 16,
                child: _buildTopRightCluster(),
              ),
              if (mapActive && _locationReady)
                Positioned(
                  top: safe.top + 10,
                  left: 14,
                  child: _buildMapActions(),
                ),
              Positioned(
                left: 14,
                right: 14,
                bottom: math.max(safe.bottom, 10) + 6,
                child: _buildBottomPanel(prompt),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Top-right corner: either the settings panel (when expanded) or a row of
  /// the hamburger settings button + the mode selector.
  Widget _buildTopRightCluster() {
    return AnimatedSize(
      duration: _uiAnimDuration,
      curve: Curves.easeOutQuart,
      alignment: Alignment.topRight,
      child: AnimatedSwitcher(
        duration: _uiAnimDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.topRight,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.topRight,
              child: child,
            ),
          );
        },
        child: _settingsExpanded
            ? _buildSettingsPanel()
            : KeyedSubtree(
                key: const ValueKey<String>('top_right_collapsed'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsButton(),
                    const SizedBox(width: 8),
                    _buildModeSelector(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _settingsExpanded = true;
          _modeMenuExpanded = false;
        });
      },
      child: _glassCard(
        borderRadius: 20,
        padding: const EdgeInsets.all(10),
        child: const Icon(
          Icons.menu_rounded,
          color: Color(0xFFF4FAFF),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final s = S.of(context);
    final settings = AppSettingsScope.maybeOf(context);

    return KeyedSubtree(
      key: const ValueKey<String>('settings_panel'),
      child: _glassCard(
        width: 250,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.settings,
                    style: const TextStyle(
                      color: Color(0xFFF4FAFF),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _settingsExpanded = false),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFFF4FAFF),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _settingsSectionLabel(s.languageLabel),
            const SizedBox(height: 6),
            for (final language in AppLanguage.values) ...[
              _settingsOption(
                label: s.languageName(language),
                selected: settings?.language == language,
                onTap: () => settings?.language = language,
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 4),
            _settingsSectionLabel(s.defaultMapApp),
            const SizedBox(height: 6),
            for (final app in availableMapApps()) ...[
              _settingsOption(
                label: s.mapAppName(app),
                selected: settings?.mapApp == app,
                onTap: () => settings?.mapApp = app,
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: const Color(0xFF06243C).withValues(alpha: 0.72),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _settingsOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: _uiAnimFastDuration,
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(
            0xFF4D6F92,
          ).withValues(alpha: selected ? 0.54 : 0.30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.30 : 0.10),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF4FAFF),
                  fontSize: 14.5,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: _uiAnimFastDuration,
              child: selected
                  ? const Icon(
                      Icons.check,
                      key: ValueKey<String>('settings_option_check'),
                      color: Colors.white,
                      size: 18,
                    )
                  : const SizedBox(
                      key: ValueKey<String>('settings_option_blank'),
                      width: 18,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapActions() {
    return Column(
      children: [
        _mapActionButton(
          icon: Icons.traffic_rounded,
          active: _trafficEnabled,
          onTap: () => setState(() => _trafficEnabled = !_trafficEnabled),
        ),
        const SizedBox(height: 10),
        _mapActionButton(
          icon: Icons.my_location_rounded,
          onTap: _recenterOnUser,
        ),
      ],
    );
  }

  Widget _mapActionButton({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _uiAnimFastDuration,
        curve: Curves.easeOutCubic,
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF58BFB7).withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.92),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 21,
          color: active ? Colors.white : const Color(0xFF2A5D66),
        ),
      ),
    );
  }

  void _recenterOnUser() {
    final location = _latestUserLocation;
    final controller = _mapController;
    if (location == null || controller == null) {
      _showHint(S.of(context).stillLocatingShort);
      AppDebugLog.log(
        'Recenter requested before a user location was available.',
      );
      return;
    }
    AppDebugLog.log('Recenter map to live user location.');
    controller.moveCamera(
      CameraUpdate.newLatLngZoom(location, 15.5),
      duration: 350,
    );
  }

  Widget _buildMapBackground() {
    if (_supportsAmap && _hasConfiguredApiKey) {
      return Stack(
        children: [
          AMapWidget(
            initialCameraPosition: _defaultCamera,
            trafficEnabled: _trafficEnabled,
            scaleEnabled: false,
            compassEnabled: false,
            markers: _selectedMarkers,
            touchPoiEnabled: true,
            myLocationStyleOptions: MyLocationStyleOptions(
              true,
              circleFillColor: const Color(0x334BD5FF),
              circleStrokeColor: const Color(0xFF1D9BD1),
              circleStrokeWidth: 1,
            ),
            onMapCreated: (AMapController controller) {
              _mapController = controller;
            },
            onPoiTouched: (AMapPoi poi) {
              _onMapPoiTapped(poi);
            },
            onLocationChanged: (AMapLocation location) {
              final lat = location.latLng.latitude;
              final lng = location.latLng.longitude;
              final hasValidLocation =
                  lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
              if (!hasValidLocation || _mapController == null) {
                return;
              }

              _latestUserLocation = location.latLng;

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
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _locationReady,
              child: AnimatedSwitcher(
                duration: _uiAnimDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _locationReady
                    ? const SizedBox.shrink()
                    : Container(
                        key: const ValueKey<String>('location_loading_overlay'),
                        color: const Color(0xFF0A1A2B),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              S.of(context).fetchingLocation,
                              style: const TextStyle(
                                color: Color(0xFFE7F8FF),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
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
    final s = S.of(context);
    final reason = !_supportsAmap ? s.amapPlatformHint : s.missingMapKeyHint;
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
    return AnimatedSize(
      duration: _uiAnimDuration,
      curve: Curves.easeOutQuart,
      alignment: Alignment.topRight,
      child: AnimatedSwitcher(
        duration: _uiAnimDuration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          // Anchor both states to the top-right corner so the expansion grows
          // out of the collapsed chip instead of jumping around its center.
          return Stack(
            alignment: Alignment.topRight,
            children: <Widget>[...previousChildren, ?currentChild],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.topRight,
              child: child,
            ),
          );
        },
        child: _modeMenuExpanded
            ? _buildExpandedModeSelector()
            : _buildCollapsedModeSelector(),
      ),
    );
  }

  Widget _buildExpandedModeSelector() {
    return KeyedSubtree(
      key: const ValueKey<String>('mode_expanded'),
      child: _glassCard(
        width: 228,
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).modeSelection,
              style: const TextStyle(
                color: Color(0xFFF4FAFF),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _modeOption(UserMode.driver, S.of(context).imTheDriver),
            const SizedBox(height: 7),
            _modeOption(UserMode.passenger, S.of(context).imThePassenger),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedModeSelector() {
    return KeyedSubtree(
      key: const ValueKey<String>('mode_collapsed'),
      child: GestureDetector(
        onTap: () => setState(() => _modeMenuExpanded = true),
        child: _glassCard(
          borderRadius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            _mode == UserMode.driver
                ? S.of(context).driverMode
                : S.of(context).passengerMode,
            style: const TextStyle(
              color: Color(0xFFF4FAFF),
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
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
        _clearAllLocations();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: _uiAnimDuration,
        curve: Curves.easeOutCubic,
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
            AnimatedSwitcher(
              duration: _uiAnimFastDuration,
              child: selected
                  ? const Icon(
                      Icons.check,
                      key: ValueKey<String>('selected_mode_icon'),
                      color: Colors.white,
                      size: 20,
                    )
                  : const SizedBox(
                      key: ValueKey<String>('unselected_mode_icon_placeholder'),
                      width: 20,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(String prompt) {
    return _glassCard(
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      // Animate panel height changes (e.g. the suggestion dropdown appearing)
      // instead of snapping.
      child: AnimatedSize(
        duration: _uiAnimDuration,
        curve: Curves.easeOutQuart,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).panelTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF06243C),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: _uiAnimDuration,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final slide =
                    Tween<Offset>(
                      begin: const Offset(0, 0.22),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                    );
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: slide, child: child),
                );
              },
              child: Text(
                prompt,
                key: ValueKey<String>(prompt),
                style: const TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
              ),
            ),
            const SizedBox(height: 8),
            _searchBar(
              controller: _pickupController,
              focusNode: _pickupFocusNode,
              hint: S.of(context).searchPlaceHint,
              field: _SearchField.pickup,
            ),
            const SizedBox(height: 7),
            Text(
              S.of(context).altStartPrompt,
              style: const TextStyle(fontSize: 20, color: Color(0xFF5C77BE)),
            ),
            const SizedBox(height: 8),
            _searchBar(
              controller: _startController,
              focusNode: _startFocusNode,
              hint: S.of(context).searchStartHint,
              field: _SearchField.start,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _startOptimizing,
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
                child: Text(
                  S.of(context).startOptimizing,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the optimization request from the current selections and open the
  /// result page. The "pickup" field always holds the other party's location;
  /// the "start" field (or live GPS) holds the user's own position.
  void _startOptimizing() {
    FocusScope.of(context).unfocus();

    final s = S.of(context);
    final pickup = _pickupSelection;
    if (pickup == null) {
      AppDebugLog.log('Optimization blocked: pickup location is missing.');
      _showHint(
        _mode == UserMode.driver ? s.selectPassengerFirst : s.selectDriverFirst,
      );
      return;
    }

    final ownStart = _startSelection?.latLng ?? _latestUserLocation;
    if (ownStart == null) {
      AppDebugLog.log(
        'Optimization blocked: start location is still unavailable.',
      );
      _showHint(s.stillLocatingLong);
      return;
    }
    final ownName = _startSelection?.name ?? s.myLocation;

    final request = _mode == UserMode.driver
        ? OptimizationRequest(
            driver: ownStart,
            driverName: ownName,
            passenger: pickup.latLng,
            passengerName: pickup.name,
            apiKey: _effectiveSearchKey,
          )
        : OptimizationRequest(
            driver: pickup.latLng,
            driverName: pickup.name,
            passenger: ownStart,
            passengerName: ownName,
            apiKey: _effectiveSearchKey,
          );

    AppDebugLog.log(
      'Start Optimization tapped: mode=${_mode.name}, pickup="${pickup.name}", start="${ownName}", backend=${hasPickupBackend ? 'configured' : 'missing'}, mapKey=${_hasConfiguredApiKey ? 'configured' : 'missing'}.',
    );
    AppDebugLog.log('Opening result screen and starting optimization work.');

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ResultPage(request: request)),
    );
  }

  void _showHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _searchBar({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required _SearchField field,
  }) {
    final showSuggestions = _activeSearchField == field;
    final isActive = showSuggestions || focusNode.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: _uiAnimDuration,
          curve: Curves.easeOutCubic,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(
              0xFF58BFB7,
            ).withValues(alpha: isActive ? 0.97 : 0.93),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: isActive ? 0.30 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF40D4C8,
                ).withValues(alpha: isActive ? 0.24 : 0.0),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFFE9FFF8), size: 27),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (String value) => _onSearchChanged(field, value),
                  style: const TextStyle(
                    color: Color(0xFFE9FFF8),
                    fontSize: 16.5,
                  ),
                  cursorColor: const Color(0xFFE9FFF8),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xD8E9FFF8),
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: _uiAnimFastDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _isSearching && showSuggestions
                    ? const SizedBox(
                        key: ValueKey<String>('search_loading'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE9FFF8),
                        ),
                      )
                    : controller.text.trim().isNotEmpty
                    ? IconButton(
                        key: const ValueKey<String>('search_clear_button'),
                        onPressed: () => _clearSearch(field),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFE9FFF8),
                          size: 21,
                        ),
                        splashRadius: 18,
                      )
                    : const SizedBox(
                        key: ValueKey<String>('search_action_empty'),
                        width: 18,
                      ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: _uiAnimFastDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: showSuggestions
              ? _buildSuggestionPanel(field, controller.text.trim())
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSuggestionPanel(_SearchField field, String query) {
    final s = S.of(context);
    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searchError != null && !_isSearching) {
      return _suggestionMessage(
        icon: Icons.info_outline,
        text: _searchError == _SearchErrorKind.missingKey
            ? s.missingWebKey
            : s.searchFailed,
      );
    }

    if (_isSearching && _suggestions.isEmpty) {
      return _suggestionMessage(
        icon: Icons.manage_search,
        text: s.searchingNearby,
      );
    }

    if (!_isSearching && _suggestions.isEmpty) {
      return _suggestionMessage(
        icon: Icons.location_searching,
        text: s.noMatchingPlaces,
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 7),
      constraints: const BoxConstraints(maxHeight: 194),
      decoration: BoxDecoration(
        color: const Color(0xC72B5A5B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _suggestions.length,
        separatorBuilder: (BuildContext _, int index) =>
            Divider(color: Colors.white.withValues(alpha: 0.14), height: 0.5),
        itemBuilder: (BuildContext context, int index) {
          final suggestion = _suggestions[index];
          return InkWell(
            onTap: () => _onSuggestionSelected(field, suggestion),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.place_outlined,
                      color: Color(0xFFCBF6EE),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEFFFF8),
                            fontSize: 14.8,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          suggestion.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD2F2EA),
                            fontSize: 12.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _suggestionMessage({required IconData icon, required String text}) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      decoration: BoxDecoration(
        color: const Color(0xC72B5A5B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFCBF6EE), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFD2F2EA), fontSize: 12.8),
            ),
          ),
        ],
      ),
    );
  }

  void _clearSearch(_SearchField field) {
    if (field == _SearchField.pickup) {
      _pickupController.clear();
      _pickupSelection = null;
    } else {
      _startController.clear();
      _startSelection = null;
    }

    _searchDebounce?.cancel();
    setState(() {
      _isSearching = false;
      _searchError = null;
      _suggestions = const <_PoiSuggestion>[];
    });

    _refreshMarkers();
  }

  void _clearAllLocations() {
    _pickupController.clear();
    _startController.clear();
    _pickupSelection = null;
    _startSelection = null;

    _searchDebounce?.cancel();
    setState(() {
      _activeSearchField = null;
      _isSearching = false;
      _searchError = null;
      _suggestions = const <_PoiSuggestion>[];
    });

    _refreshMarkers();
  }

  void _onSearchChanged(_SearchField field, String rawValue) {
    final query = rawValue.trim();
    if (_activeSearchField != field) {
      setState(() {
        _activeSearchField = field;
      });
    }

    if (query.isEmpty) {
      _searchDebounce?.cancel();
      setState(() {
        _searchError = null;
        _isSearching = false;
        _suggestions = const <_PoiSuggestion>[];
      });
      return;
    }

    _searchDebounce?.cancel();
    setState(() {
      _searchError = null;
      _isSearching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _searchPoiSuggestions(field, query);
    });
  }

  Future<void> _searchPoiSuggestions(_SearchField field, String query) async {
    final key = _effectiveSearchKey;
    if (key.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = _SearchErrorKind.missingKey;
        _suggestions = const <_PoiSuggestion>[];
      });
      return;
    }

    final requestToken = ++_searchRequestToken;
    try {
      final tips = await _fetchFromInputTips(query: query, key: key);
      final merged = tips.isNotEmpty
          ? tips
          : await _fetchFromKeywordSearch(query: query, key: key);

      if (!mounted || requestToken != _searchRequestToken) return;
      setState(() {
        _searchError = null;
        _suggestions = merged;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || requestToken != _searchRequestToken) return;
      setState(() {
        _isSearching = false;
        _suggestions = const <_PoiSuggestion>[];
        _searchError = _SearchErrorKind.failed;
      });
    }
  }

  Future<List<_PoiSuggestion>> _fetchFromInputTips({
    required String query,
    required String key,
  }) async {
    final params = <String, String>{
      'key': key,
      'keywords': query,
      'datatype': 'poi',
      'output': 'JSON',
    };

    final location = _latestUserLocation;
    if (location != null) {
      params['location'] =
          '${location.longitude.toStringAsFixed(6)},${location.latitude.toStringAsFixed(6)}';
    }

    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/assistant/inputtips',
      params,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if ('${data['status']}' != '1') {
      throw StateError('${data['info'] ?? 'AMap request failed'}');
    }

    final tips = (data['tips'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    final results = <_PoiSuggestion>[];
    for (final item in tips) {
      final parsed = _parseSuggestionFromTip(item);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results.take(10).toList(growable: false);
  }

  Future<List<_PoiSuggestion>> _fetchFromKeywordSearch({
    required String query,
    required String key,
  }) async {
    final params = <String, String>{
      'key': key,
      'keywords': query,
      'offset': '10',
      'page': '1',
      'extensions': 'base',
      'output': 'JSON',
    };

    final uri = Uri.https('restapi.amap.com', '/v3/place/text', params);
    final response = await http.get(uri).timeout(const Duration(seconds: 8));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if ('${data['status']}' != '1') {
      throw StateError('${data['info'] ?? 'AMap request failed'}');
    }

    final pois = (data['pois'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    final results = <_PoiSuggestion>[];
    for (final item in pois) {
      final parsed = _parseSuggestionFromPoi(item);
      if (parsed != null) {
        results.add(parsed);
      }
    }

    return results;
  }

  _PoiSuggestion? _parseSuggestionFromTip(Map<String, dynamic> item) {
    final location = (item['location'] ?? '').toString();
    final latLng = _parseLatLng(location);
    if (latLng == null) {
      return null;
    }

    final name = (item['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return null;
    }

    final district = (item['district'] ?? '').toString().trim();
    final address = (item['address'] ?? '').toString().trim();
    final id = (item['id'] ?? '').toString().trim();

    return _PoiSuggestion(
      id: id.isNotEmpty ? id : '${name}_${latLng.latitude}_${latLng.longitude}',
      name: name,
      address: address,
      latLng: latLng,
      district: district,
    );
  }

  _PoiSuggestion? _parseSuggestionFromPoi(Map<String, dynamic> item) {
    final location = (item['location'] ?? '').toString();
    final latLng = _parseLatLng(location);
    if (latLng == null) {
      return null;
    }

    final name = (item['name'] ?? '').toString().trim();
    if (name.isEmpty) {
      return null;
    }

    final adname = (item['adname'] ?? '').toString().trim();
    final cityname = (item['cityname'] ?? '').toString().trim();
    final district = [cityname, adname].where((e) => e.isNotEmpty).join(' ');

    final address = (item['address'] ?? '').toString().trim();
    final id = (item['id'] ?? '').toString().trim();

    return _PoiSuggestion(
      id: id.isNotEmpty ? id : '${name}_${latLng.latitude}_${latLng.longitude}',
      name: name,
      address: address,
      latLng: latLng,
      district: district,
    );
  }

  LatLng? _parseLatLng(String value) {
    final parts = value.split(',');
    if (parts.length != 2) return null;

    final lng = double.tryParse(parts[0]);
    final lat = double.tryParse(parts[1]);
    if (lng == null || lat == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;

    return LatLng(lat, lng);
  }

  Future<void> _onSuggestionSelected(
    _SearchField field,
    _PoiSuggestion suggestion,
  ) async {
    if (field == _SearchField.pickup) {
      _pickupSelection = suggestion;
      _pickupController.text = suggestion.name;
      _pickupController.selection = TextSelection.collapsed(
        offset: _pickupController.text.length,
      );
      _pickupFocusNode.unfocus();
    } else {
      _startSelection = suggestion;
      _startController.text = suggestion.name;
      _startController.selection = TextSelection.collapsed(
        offset: _startController.text.length,
      );
      _startFocusNode.unfocus();
    }

    setState(() {
      _activeSearchField = null;
      _isSearching = false;
      _searchError = null;
      _suggestions = const <_PoiSuggestion>[];
    });

    _refreshMarkers();

    if (_mapController != null) {
      await _mapController!.moveCamera(
        CameraUpdate.newLatLngZoom(suggestion.latLng, 16.0),
        duration: 350,
      );
    }
  }

  void _refreshMarkers() {
    final markers = <Marker>{};

    if (_pickupSelection != null) {
      markers.add(
        Marker(
          position: _pickupSelection!.latLng,
          infoWindow: InfoWindow(
            title: _pickupSelection!.name,
            snippet: _pickupSelection!.subtitle,
          ),
        ),
      );
    }

    if (_startSelection != null) {
      markers.add(
        Marker(
          position: _startSelection!.latLng,
          infoWindow: InfoWindow(
            title: _startSelection!.name,
            snippet: _startSelection!.subtitle,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _selectedMarkers = markers;
    });
  }

  void _onMapPoiTapped(AMapPoi poi) {
    final location = poi.latLng;
    if (location == null) return;

    _showPoiSelectionBottomSheet(poi, location);
  }

  void _showPoiSelectionBottomSheet(AMapPoi poi, LatLng latLng) {
    FocusScope.of(context).unfocus();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xC72B5A5B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with POI name
                Row(
                  children: [
                    const Icon(Icons.place, color: Color(0xFFCBF6EE), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name ?? S.of(context).unknownLocation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFEFFFF8),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action buttons
                if (_mode == UserMode.driver) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _setPickupFromPoi(poi, latLng);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF5FC99E,
                        ).withValues(alpha: 0.88),
                        foregroundColor: const Color(0xFFEFFFF8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        S.of(context).myPassengerIsHere,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _setStartFromPoi(poi, latLng);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEFFFF8),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        S.of(context).illGoFromHere,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        _setPickupFromPoi(poi, latLng);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF5FC99E,
                        ).withValues(alpha: 0.88),
                        foregroundColor: const Color(0xFFEFFFF8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        S.of(context).myDriverIsHere,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _setStartFromPoi(poi, latLng);
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEFFFF8),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: Text(
                        S.of(context).imHere,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _setPickupFromPoi(AMapPoi poi, LatLng latLng) {
    final suggestion = _PoiSuggestion(
      id: poi.id ?? '${poi.name}_${latLng.latitude}_${latLng.longitude}',
      name: poi.name ?? S.of(context).unknownLocation,
      address: '',
      latLng: latLng,
      district: '',
    );

    _pickupSelection = suggestion;
    _pickupController.text = suggestion.name;
    _pickupController.selection = TextSelection.collapsed(
      offset: _pickupController.text.length,
    );

    setState(() {
      _activeSearchField = null;
    });

    _refreshMarkers();
  }

  void _setStartFromPoi(AMapPoi poi, LatLng latLng) {
    final suggestion = _PoiSuggestion(
      id: poi.id ?? '${poi.name}_${latLng.latitude}_${latLng.longitude}',
      name: poi.name ?? S.of(context).unknownLocation,
      address: '',
      latLng: latLng,
      district: '',
    );

    _startSelection = suggestion;
    _startController.text = suggestion.name;
    _startController.selection = TextSelection.collapsed(
      offset: _startController.text.length,
    );

    setState(() {
      _activeSearchField = null;
    });

    _refreshMarkers();
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
        // Moderate blur: visually identical on glass cards but measurably
        // cheaper than the previous sigma 16 on devices.
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
