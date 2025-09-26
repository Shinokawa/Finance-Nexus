import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'app_theme_mode';
const _autoRefreshKey = 'analytics_auto_refresh';

enum AppThemeMode {
  system,
  light,
  dark,
}

extension AppThemeModeLabel on AppThemeMode {
  String get label {
    switch (this) {
      case AppThemeMode.system:
        return '跟随系统';
      case AppThemeMode.light:
        return '浅色模式';
      case AppThemeMode.dark:
        return '深色模式';
    }
  }

  Brightness resolveBrightness(Brightness platformBrightness) {
    switch (this) {
      case AppThemeMode.system:
        return platformBrightness;
      case AppThemeMode.light:
        return Brightness.light;
      case AppThemeMode.dark:
        return Brightness.dark;
    }
  }

  static AppThemeMode fromName(String? name) {
    return AppThemeMode.values
        .firstWhere((value) => value.name == name, orElse: () => AppThemeMode.system);
  }
}

@immutable
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.analyticsAutoRefresh,
  });

  final AppThemeMode themeMode;
  final bool analyticsAutoRefresh;

  factory AppSettings.initial() => const AppSettings(
        themeMode: AppThemeMode.system,
        analyticsAutoRefresh: true,
      );

  AppSettings copyWith({
    AppThemeMode? themeMode,
    bool? analyticsAutoRefresh,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      analyticsAutoRefresh: analyticsAutoRefresh ?? this.analyticsAutoRefresh,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings.initial()) {
    _load();
  }

  SharedPreferences? _preferences;
  bool _loading = false;
  bool _preferencesUnavailable = false;
  bool _hasLoggedLoadError = false;

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final prefs = await _ensurePreferences();
    if (prefs != null) {
      final storedTheme = prefs.getString(_themeModeKey);
      final storedAutoRefresh = prefs.getBool(_autoRefreshKey);

      state = state.copyWith(
        themeMode: AppThemeModeLabel.fromName(storedTheme),
        analyticsAutoRefresh: storedAutoRefresh ?? state.analyticsAutoRefresh,
      );
    }
    _loading = false;
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
      if (!_hasLoggedLoadError) {
        debugPrint('[Settings] 首选项功能不可用: $error');
        _hasLoggedLoadError = true;
      }
      _preferencesUnavailable = true;
      return null;
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await _ensurePreferences();
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setString(_themeModeKey, mode.name);
    } catch (error) {
      debugPrint('[Settings] 保存主题失败: $error');
      _preferencesUnavailable = true;
    }
  }

  Future<void> setAnalyticsAutoRefresh(bool enabled) async {
    state = state.copyWith(analyticsAutoRefresh: enabled);
    final prefs = await _ensurePreferences();
    if (prefs == null) {
      return;
    }
    try {
      await prefs.setBool(_autoRefreshKey, enabled);
    } catch (error) {
      debugPrint('[Settings] 保存自动刷新开关失败: $error');
      _preferencesUnavailable = true;
    }
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});
