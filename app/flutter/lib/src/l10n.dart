import 'package:flutter/widgets.dart';

import 'app_settings.dart';
import 'pickup_optimizer.dart';

/// Lightweight string table for the three supported display languages.
///
/// Every getter resolves through `_t(en, zh, ja)`. Looked up via [S.of];
/// widgets depending on it rebuild when the language changes because the
/// lookup goes through [AppSettingsScope]. Falls back to English when no
/// scope is present (e.g. bare widget tests).
class S {
  const S(this.language);

  final AppLanguage language;

  static S of(BuildContext context) {
    final settings = AppSettingsScope.maybeOf(context);
    return S(settings?.language ?? AppLanguage.en);
  }

  String _t(String en, String zh, String ja) {
    return switch (language) {
      AppLanguage.en => en,
      AppLanguage.zhHans => zh,
      AppLanguage.ja => ja,
    };
  }

  // --- Dashboard ---------------------------------------------------------

  String get panelTitle => _t('Pick up Optimization', '接驾优化', 'ピックアップ最適化');
  String get driverMode => _t('Driver Mode', '司机模式', 'ドライバーモード');
  String get passengerMode => _t('Passenger Mode', '乘客模式', '乗客モード');
  String get modeSelection => _t('Mode Selection', '模式选择', 'モード選択');
  String get imTheDriver => _t("I'm the driver", '我是司机', '私はドライバー');
  String get imThePassenger => _t("I'm the passenger", '我是乘客', '私は乗客');
  String get promptDriver =>
      _t("Where's your passenger?", '你的乘客在哪里？', '乗客はどこですか？');
  String get promptPassenger =>
      _t("Where's your driver?", '你的司机在哪里？', 'ドライバーはどこですか？');
  String get altStartPrompt =>
      _t('Starting from a different location?', '从其他地点出发？', '別の場所から出発しますか？');
  String get searchPlaceHint =>
      _t('Search for a place or address', '搜索地点或地址', '場所や住所を検索');
  String get searchStartHint =>
      _t('Search your start point', '搜索出发地点', '出発地点を検索');
  String get startOptimizing =>
      _t('Start Route Optimizing', '开始路线优化', 'ルート最適化を開始');
  String get fetchingLocation =>
      _t('Fetching current location...', '正在获取当前位置…', '現在地を取得中…');
  String get searchingNearby =>
      _t('Searching nearby places...', '正在搜索附近地点…', '近くの場所を検索中…');
  String get noMatchingPlaces =>
      _t('No matching places found.', '未找到匹配的地点。', '一致する場所が見つかりません。');
  String get searchFailed => _t(
    'Search failed. Please check your network and key settings.',
    '搜索失败，请检查网络与 Key 配置。',
    '検索に失敗しました。ネットワークとキー設定を確認してください。',
  );
  String get missingWebKey => _t(
    'Missing AMAP_WEB_KEY. Please configure a Web Service key.',
    '缺少 AMAP_WEB_KEY，请配置 Web 服务 Key。',
    'AMAP_WEB_KEY がありません。Web サービスキーを設定してください。',
  );
  String get amapPlatformHint => _t(
    'AMap is available on iOS and Android only.',
    '高德地图仅支持 iOS 和 Android。',
    '地図表示は iOS と Android のみ対応しています。',
  );
  String get missingMapKeyHint => _t(
    'Missing AMAP API key. Pass keys with --dart-define.',
    '缺少高德 API Key，请通过 --dart-define 传入。',
    'AMAP API キーがありません。--dart-define で渡してください。',
  );
  String get unknownLocation => _t('Unknown Location', '未知地点', '不明な場所');
  String get myPassengerIsHere =>
      _t('My passenger is here', '乘客在这里', '乗客はここにいます');
  String get illGoFromHere => _t("I'll go from here", '我从这里出发', 'ここから出発します');
  String get myDriverIsHere => _t('My driver is here', '司机在这里', 'ドライバーはここにいます');
  String get imHere => _t("I'm here", '我在这里', '私はここにいます');
  String get selectPassengerFirst => _t(
    "Select your passenger's location first.",
    '请先选择乘客的位置。',
    '先に乗客の場所を選択してください。',
  );
  String get selectDriverFirst => _t(
    "Select your driver's location first.",
    '请先选择司机的位置。',
    '先にドライバーの場所を選択してください。',
  );
  String get stillLocatingLong => _t(
    'Still locating you — wait a moment or set a start point.',
    '正在定位中——请稍候或手动设置出发点。',
    '位置情報を取得中です。少し待つか出発地点を設定してください。',
  );
  String get stillLocatingShort => _t(
    'Still locating you — one moment.',
    '正在定位中，请稍候。',
    '位置情報を取得中です。少々お待ちください。',
  );
  String get myLocation => _t('My location', '我的位置', '現在地');

  // --- Settings ----------------------------------------------------------

  String get settings => _t('Settings', '设置', '設定');
  String get languageLabel => _t('Language', '语言', '言語');
  String get defaultMapApp => _t('Default map app', '默认地图应用', '既定の地図アプリ');

  /// Language options name themselves in their own language on purpose.
  String languageName(AppLanguage value) {
    return switch (value) {
      AppLanguage.en => 'English',
      AppLanguage.zhHans => '简体中文',
      AppLanguage.ja => '日本語',
    };
  }

  String mapAppName(MapAppChoice value) {
    return switch (value) {
      MapAppChoice.amap => _t('AMap', '高德地图', '高徳地図 (AMap)'),
      MapAppChoice.appleMaps => _t('Apple Maps', 'Apple 地图', 'Apple マップ'),
      MapAppChoice.baiduMaps => _t('Baidu Maps', '百度地图', '百度地図'),
      MapAppChoice.browser => _t('Browser', '浏览器', 'ブラウザ'),
    };
  }

  // --- Mobility modes ------------------------------------------------------

  /// Sentence verb: "Walk 5 mins to ..." / "步行约 5 分钟到 ..." .
  String modeVerb(MobilityMode mode) {
    return switch (mode) {
      MobilityMode.walking => _t('Walk', '步行', '徒歩'),
      MobilityMode.bicycle => _t('Ride a bicycle', '骑行', '自転車'),
      MobilityMode.transit => _t('Take transit', '乘坐公交', '公共交通機関'),
    };
  }

  /// Short noun for list tiles.
  String modeName(MobilityMode mode) {
    return switch (mode) {
      MobilityMode.walking => _t('Walk', '步行', '徒歩'),
      MobilityMode.bicycle => _t('Bicycle', '骑行', '自転車'),
      MobilityMode.transit => _t('Transit', '公交', '公共交通'),
    };
  }

  // --- Result page ---------------------------------------------------------

  String get optimizationResult => _t('Optimization Result', '优化结果', '最適化結果');
  String get badgeLiveTraffic => _t('Live traffic', '实时路况', 'リアルタイム交通');
  String get badgeLiveEstimates => _t('Live + estimates', '实时+估算', 'ライブ+推定');
  String get badgeEstimatesOnly => _t('Estimates only', '仅估算', '推定のみ');
  String get optimizingTitle =>
      _t('Optimizing your pickup...', '正在优化接驾方案…', 'ピックアップを最適化中…');
  String get optimizingSubtitle => _t(
    'Checking traffic and meeting points along the route',
    '正在分析沿途路况与候选会合点',
    'ルート沿いの交通と合流地点を確認しています',
  );
  String get optimizationFailed =>
      _t('Optimization failed', '优化失败', '最適化に失敗しました');
  String get tryAgain => _t('Try again', '重试', '再試行');
  String get suggestionsLabel => _t('SUGGESTIONS', '推荐方案', '候補プラン');
  String get stayPutTile => _t('Stay put', '原地等待', 'その場で待つ');
  String get stayPutSubtitle =>
      _t('Wait — the driver comes to you', '等待司机直接来接你', 'ドライバーが迎えに来ます');
  String meetAt(String name) => _t('Meet at $name', '在 $name 会合', '$name で合流');
  String minutesShort(int mins) => _t('$mins min', '$mins 分钟', '$mins 分');
  String tileTitle(MobilityMode mode, int mins) =>
      '${modeName(mode)} ${minutesShort(mins)}';
  String get baselineTag => _t('baseline', '基准', '基準');
  String driverSavesTag(int mins) =>
      _t('driver −$mins min', '司机省 $mins 分钟', '運転 −$mins 分');
  String get cardFastest => _t('FASTEST', '最快方案', '最速プラン');
  String get cardAlternative => _t('ALTERNATIVE', '备选方案', '代替プラン');
  String get cardStayPut => _t('STAY PUT', '原地等待', 'その場で待機');
  String get passengerStayLine => _t(
    'Passenger: Stay at the pickup point',
    '乘客：在上车点原地等待',
    '乗客：乗車地点でお待ちください',
  );
  String passengerGoLine(MobilityMode mode, int mins, String name) => _t(
    'Passenger: ${modeVerb(mode)} $mins mins to $name',
    '乘客：${modeVerb(mode)}约 $mins 分钟到 $name',
    '乗客：$name まで${modeVerb(mode)}で約 $mins 分',
  );
  String driverArriveLine(int mins, {required bool directFastest}) {
    final base = _t(
      'Driver: Arrive in $mins mins',
      '司机：约 $mins 分钟到达',
      'ドライバー：約 $mins 分で到着',
    );
    if (!directFastest) return base;
    return base +
        _t(' — the direct route is already fastest', '——直接前往已是最快', '（直行が最速です）');
  }

  String driverSaveLine(int mins) => _t(
    'Driver: Save $mins mins driving time',
    '司机：节省 $mins 分钟车程',
    'ドライバー：運転時間を $mins 分短縮',
  );
  String get meetingUpLocation => _t('MEETING UP LOCATION:', '会合地点：', '合流地点：');
  String get share => _t('Share', '分享', '共有');
  String get openInMaps => _t('Open in Maps', '在地图中打开', '地図で開く');
  String get planCopied => _t(
    'Pickup plan copied — paste it anywhere to share',
    '接驾方案已复制，可随处粘贴分享',
    'プランをコピーしました。貼り付けて共有できます',
  );
  String get cannotOpenMapApp =>
      _t('Could not open the map application', '无法打开地图应用', '地図アプリを開けませんでした');
  String chipDrive(int mins) =>
      _t('Drive $mins min', '驾车 $mins 分钟', '運転 $mins 分');
  String chipPassengerGo(
    MobilityMode mode,
    int mins, {
    required bool suggested,
  }) =>
      '${modeVerb(mode)} ${minutesShort(mins)}'
      '${suggested ? _t(' · Suggested', ' · 推荐', '・おすすめ') : ''}';
  String get chipStaysPut => _t('Passenger stays put', '乘客原地等待', '乗客はその場で待機');
  String get fallbackMeetingName =>
      _t("a point on the driver's route", '司机路线上的会合点', 'ドライバーのルート上の地点');
  String markerDriver(String name) =>
      _t('Driver: $name', '司机：$name', 'ドライバー：$name');
  String markerPassenger(String name) =>
      _t('Passenger: $name', '乘客：$name', '乗客：$name');
  String markerMeetHere(String name) =>
      _t('Meet here: $name', '会合点：$name', '合流地点：$name');

  // --- Share text ----------------------------------------------------------

  String get shareTitle => _t(
    'Pickup plan — Picking-Up Optimization',
    '接驾方案 — 接驾优化',
    'ピックアップ計画 — Picking-Up Optimization',
  );
  String shareMeetAt(String name) =>
      _t('Meet at: $name', '会合地点：$name', '合流地点：$name');
  String shareAddress(String address) =>
      _t('Address: $address', '地址：$address', '住所：$address');
  String sharePassenger(MobilityMode mode, int mins) => _t(
    'Passenger: ${modeVerb(mode).toLowerCase()} ~$mins min',
    '乘客：${modeVerb(mode)}约 $mins 分钟',
    '乗客：${modeVerb(mode)}で約 $mins 分',
  );
  String shareDriver(int mins, {int? savedMins}) {
    final base = _t(
      'Driver: arrives in ~$mins min',
      '司机：约 $mins 分钟到达',
      'ドライバー：約 $mins 分で到着',
    );
    if (savedMins == null) return base;
    return base +
        _t(
          ', saves ~$savedMins min',
          '，节省约 $savedMins 分钟',
          '、約 $savedMins 分短縮',
        );
  }
}
