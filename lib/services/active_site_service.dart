import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/discourse_site.dart';

/// 当前社区选择。
///
/// 必须在任何网络单例初始化前调用 [initialize]，从而保证 Dio、Cookie 与
/// WebView 首次创建时就使用正确域名。
class ActiveSiteService {
  ActiveSiteService._();
  static final ActiveSiteService instance = ActiveSiteService._();

  static const String preferenceKey = 'active_discourse_site';

  SharedPreferences? _preferences;
  DiscourseSite _current = DiscourseSiteRegistry.defaultSite;
  bool _initialized = false;

  final ValueNotifier<DiscourseSite> activeSiteNotifier =
      ValueNotifier<DiscourseSite>(DiscourseSiteRegistry.defaultSite);
  final ValueNotifier<bool> transitionNotifier = ValueNotifier<bool>(false);

  DiscourseSite get current => _current;
  bool get isInitialized => _initialized;
  bool get isLinuxDo => _current.id == DiscourseSiteRegistry.linuxDoId;

  Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    final stored = preferences.getString(preferenceKey);
    _current =
        DiscourseSiteRegistry.byId(stored) ?? DiscourseSiteRegistry.defaultSite;
    activeSiteNotifier.value = _current;
    _initialized = true;
  }

  /// 先切换同步运行时值并持久化，但不立即重建 Widget 树。
  ///
  /// [SiteSwitchCoordinator] 会利用这个窗口重建目标站点的网络服务，完成后
  /// 再调用 [publish]，避免 UI 已开始请求而单例仍指向旧站点。
  Future<void> stage(DiscourseSite site) async {
    if (!_initialized) {
      throw StateError('ActiveSiteService.initialize() 尚未调用');
    }
    _current = site;
    await _preferences!.setString(preferenceKey, site.id);
  }

  /// 通知根组件先卸载旧 Navigator / ProviderScope。此时 [current] 仍是旧站点，
  /// 因此旧页面在卸载帧内不会突然读到目标站点配置。
  void beginTransition() {
    if (transitionNotifier.value) return;
    transitionNotifier.value = true;
  }

  void finishTransition() {
    if (!transitionNotifier.value) return;
    transitionNotifier.value = false;
  }

  void publish() {
    if (activeSiteNotifier.value.id == _current.id) return;
    activeSiteNotifier.value = _current;
  }

  String scopedStorageKey(String legacyKey) =>
      _current.scopedStorageKey(legacyKey);

  String scopedAccountId(String username) => _current.scopedAccountId(username);
}
