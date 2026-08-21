import 'package:shared_preferences/shared_preferences.dart';

import '../config/discourse_site.dart';

/// IDC Flare 专用版的固定站点状态。
///
/// 必须在任何网络单例初始化前调用 [initialize]，从而保证 Dio、Cookie 与
/// WebView 首次创建时就使用 IDC Flare。历史版本保存的 Linux.do 选择会被
/// 忽略并覆盖，专用版不存在运行时切换。
class ActiveSiteService {
  ActiveSiteService._();
  static final ActiveSiteService instance = ActiveSiteService._();

  static const String preferenceKey = 'active_discourse_site';

  DiscourseSite _current = DiscourseSiteRegistry.defaultSite;
  bool _initialized = false;

  DiscourseSite get current => _current;
  bool get isInitialized => _initialized;

  Future<void> initialize(SharedPreferences preferences) async {
    _current = DiscourseSiteRegistry.idcFlare;
    await preferences.setString(preferenceKey, _current.id);
    _initialized = true;
  }

  String scopedStorageKey(String legacyKey) =>
      _current.scopedStorageKey(legacyKey);

  String scopedAccountId(String username) => _current.scopedAccountId(username);
}
