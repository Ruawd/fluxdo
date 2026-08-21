// ignore: depend_on_referenced_packages
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import '../services/active_site_service.dart';

/// 已固定的分类 ID 列表（用于首页分类 Tab）
class PinnedCategoriesNotifier extends StateNotifier<List<int>> {
  final SharedPreferences _prefs;
  final String _key;

  factory PinnedCategoriesNotifier(SharedPreferences prefs) {
    final key = ActiveSiteService.instance.scopedStorageKey(
      'pinned_category_ids',
    );
    return PinnedCategoriesNotifier._(prefs, key);
  }

  PinnedCategoriesNotifier._(SharedPreferences prefs, String key)
    : _prefs = prefs,
      _key = key,
      super(_load(prefs, key));

  static List<int> _load(SharedPreferences prefs, String key) {
    final list = prefs.getStringList(key);
    if (list == null) return [];
    return list.map((s) => int.tryParse(s)).whereType<int>().toList();
  }

  void add(int categoryId) {
    if (state.contains(categoryId)) return;
    state = [...state, categoryId];
    _save();
  }

  void remove(int categoryId) {
    state = state.where((id) => id != categoryId).toList();
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _save();
  }

  void _save() {
    _prefs.setStringList(_key, state.map((id) => id.toString()).toList());
  }
}

final pinnedCategoriesProvider =
    StateNotifierProvider<PinnedCategoriesNotifier, List<int>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider);
      return PinnedCategoriesNotifier(prefs);
    });
