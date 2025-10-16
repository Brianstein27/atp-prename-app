import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'app_theme_mode';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themePreferenceKey);
    switch (stored) {
      case 'light':
        _mode = ThemeMode.light;
        break;
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    switch (newMode) {
      case ThemeMode.light:
        await prefs.setString(_themePreferenceKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_themePreferenceKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.remove(_themePreferenceKey);
        break;
    }
  }
}
