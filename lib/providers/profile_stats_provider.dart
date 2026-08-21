import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile_stats_config.dart';
import 'theme_provider.dart'; // sharedPreferencesProvider
import '../services/active_site_service.dart';

/// 统计卡片配置 Provider
class ProfileStatsConfigNotifier extends Notifier<ProfileStatsConfig> {
  Timer? _saveTimer;
  late String _configKey;
  late SharedPreferences _prefs;
  ProfileStatsConfig? _pendingSave;

  @override
  ProfileStatsConfig build() {
    _configKey = ActiveSiteService.instance.scopedStorageKey(
      'profile_stats_config',
    );
    _prefs = ref.watch(sharedPreferencesProvider);
    ref.onDispose(() {
      _saveTimer?.cancel();
      final pending = _pendingSave;
      if (pending != null) {
        _prefs.setString(_configKey, pending.toJsonString());
      }
    });
    final jsonStr = _prefs.getString(_configKey);
    if (jsonStr != null) {
      try {
        return ProfileStatsConfig.fromJsonString(jsonStr);
      } catch (_) {
        // 配置损坏，使用默认值
      }
    }
    return const ProfileStatsConfig();
  }

  void update(ProfileStatsConfig config) {
    state = config;
    _save(config);
  }

  void setLayoutMode(StatsLayoutMode mode) {
    update(state.copyWith(layoutMode: mode));
  }

  void setColumnsPerRow(int columns) {
    update(state.copyWith(columnsPerRow: columns));
  }

  void setDataSource(StatsDataSource source) {
    // 切换数据源时，自动移除不兼容的统计项
    final compatible = state.enabledStats
        .where((s) => isStatCompatible(s, source))
        .toList();
    update(state.copyWith(dataSource: source, enabledStats: compatible));
  }

  void setEnabledStats(List<ProfileStatType> stats) {
    update(state.copyWith(enabledStats: stats));
  }

  void addStat(ProfileStatType stat) {
    if (!state.enabledStats.contains(stat)) {
      update(state.copyWith(enabledStats: [...state.enabledStats, stat]));
    }
  }

  void removeStat(ProfileStatType stat) {
    update(
      state.copyWith(
        enabledStats: state.enabledStats.where((s) => s != stat).toList(),
      ),
    );
  }

  void reorderStats(int oldIndex, int newIndex) {
    final stats = List<ProfileStatType>.from(state.enabledStats);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = stats.removeAt(oldIndex);
    stats.insert(newIndex, item);
    update(state.copyWith(enabledStats: stats));
  }

  /// 防抖保存（300ms 内多次操作只写一次磁盘）
  void _save(ProfileStatsConfig config) {
    _saveTimer?.cancel();
    _pendingSave = config;
    _saveTimer = Timer(const Duration(milliseconds: 300), () {
      _prefs.setString(_configKey, config.toJsonString());
      _pendingSave = null;
    });
  }
}

final profileStatsConfigProvider =
    NotifierProvider<ProfileStatsConfigNotifier, ProfileStatsConfig>(
      ProfileStatsConfigNotifier.new,
    );
