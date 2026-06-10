import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, zhHans, ja }

enum MapAppChoice { amap, appleMaps, baiduMaps, browser }

/// User preferences (display language, default map application), persisted
/// with SharedPreferences and exposed app-wide via [AppSettingsScope].
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs, this._language, this._mapApp);

  /// In-memory instance for tests and as a scope-less fallback.
  @visibleForTesting
  AppSettings.inMemory({
    AppLanguage language = AppLanguage.en,
    MapAppChoice mapApp = MapAppChoice.amap,
  }) : _prefs = null,
       _language = language,
       _mapApp = mapApp;

  static const String _languageKey = 'app_language';
  static const String _mapAppKey = 'default_map_app';

  final SharedPreferences? _prefs;
  AppLanguage _language;
  MapAppChoice _mapApp;

  AppLanguage get language => _language;
  MapAppChoice get mapApp => _mapApp;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final language =
        _languageByName(prefs.getString(_languageKey)) ??
        _systemDefaultLanguage();
    final mapApp =
        _mapAppByName(prefs.getString(_mapAppKey)) ?? MapAppChoice.amap;
    return AppSettings._(prefs, language, mapApp);
  }

  /// First launch: follow the device language when it is one we support.
  static AppLanguage _systemDefaultLanguage() {
    final locale = PlatformDispatcher.instance.locale;
    return switch (locale.languageCode) {
      'zh' => AppLanguage.zhHans,
      'ja' => AppLanguage.ja,
      _ => AppLanguage.en,
    };
  }

  static AppLanguage? _languageByName(String? name) {
    for (final value in AppLanguage.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static MapAppChoice? _mapAppByName(String? name) {
    for (final value in MapAppChoice.values) {
      if (value.name == name) return value;
    }
    return null;
  }

  set language(AppLanguage value) {
    if (value == _language) return;
    _language = value;
    _prefs?.setString(_languageKey, value.name);
    notifyListeners();
  }

  set mapApp(MapAppChoice value) {
    if (value == _mapApp) return;
    _mapApp = value;
    _prefs?.setString(_mapAppKey, value.name);
    notifyListeners();
  }
}

/// Inherited access to [AppSettings]; dependents rebuild on changes.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>()
        ?.notifier;
  }
}
