import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 预设的支出类别
const List<String> predefinedCategories = [
  // 饮食
  '餐饮',
  '外卖',
  '零食',
  '咖啡茶饮',
  
  // 交通
  '交通出行',
  '打车',
  '公交地铁',
  '加油',
  '停车费',
  
  // 生活
  '日用品',
  '服装鞋包',
  '美容护理',
  '理发',
  '洗衣',
  
  // 居住
  '房租',
  '水电煤',
  '物业费',
  '家具家电',
  '房屋维修',
  
  // 娱乐
  '电影演出',
  '游戏娱乐',
  '旅游',
  '运动健身',
  '书籍',
  
  // 医疗
  '医疗费',
  '药品',
  '体检',
  
  // 教育
  '学费',
  '培训',
  '考试费',
  
  // 社交
  '聚餐',
  '礼品',
  '红包',
  
  // 其他
  '通讯费',
  '保险',
  '税费',
  '捐赠',
  '其他',
];

const _customCategoriesKey = 'ledger_custom_categories';

// 自定义类别管理
class CustomCategoriesNotifier extends StateNotifier<Set<String>> {
  CustomCategoriesNotifier() : super(<String>{}) {
    _load();
  }

  SharedPreferences? _preferences;
  bool _preferencesUnavailable = false;
  bool _isLoading = false;

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;
    final prefs = await _ensurePreferences();
    if (prefs != null) {
      final stored = prefs.getStringList(_customCategoriesKey);
      if (stored != null && stored.isNotEmpty) {
        final normalized = stored
            .map((category) => category.trim())
            .where((category) => category.isNotEmpty)
            .toSet();
        if (normalized.isNotEmpty) {
          state = normalized;
        }
      }
    }
    _isLoading = false;
  }

  Future<SharedPreferences?> _ensurePreferences() async {
    if (_preferencesUnavailable) {
      return null;
    }
    if (_preferences != null) {
      return _preferences;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      _preferences = prefs;
      return prefs;
    } catch (error) {
      debugPrint('[Category] SharedPreferences unusable: $error');
      _preferencesUnavailable = true;
      return null;
    }
  }

  void addCategory(String category) {
    final trimmed = category.trim();
    if (trimmed.isEmpty) {
      return;
    }
    if (state.contains(trimmed)) {
      return;
    }
    state = {...state, trimmed};
    unawaited(_persistCategories());
  }

  void removeCategory(String category) {
    if (!state.contains(category)) {
      return;
    }
    state = state.where((cat) => cat != category).toSet();
    unawaited(_persistCategories());
  }

  void clearCategories() {
    if (state.isEmpty) {
      return;
    }
    state = <String>{};
    unawaited(_persistCategories());
  }

  Future<void> _persistCategories() async {
    final prefs = await _ensurePreferences();
    if (prefs == null) {
      return;
    }
    try {
      final sortedCategories = state.toList()..sort();
      await prefs.setStringList(_customCategoriesKey, sortedCategories);
    } catch (error) {
      debugPrint('[Category] Failed to persist custom categories: $error');
      _preferencesUnavailable = true;
    }
  }
}

final customCategoriesProvider = StateNotifierProvider<CustomCategoriesNotifier, Set<String>>((ref) {
  return CustomCategoriesNotifier();
});

// 获取所有可用类别（预设 + 自定义）
final allCategoriesProvider = Provider<List<String>>((ref) {
  final customCategories = ref.watch(customCategoriesProvider);
  final allCategories = <String>[];
  
  // 先添加预设类别
  allCategories.addAll(predefinedCategories);
  
  // 再添加自定义类别（去重）
  for (final custom in customCategories) {
    if (!allCategories.contains(custom)) {
      allCategories.add(custom);
    }
  }
  
  return allCategories;
});