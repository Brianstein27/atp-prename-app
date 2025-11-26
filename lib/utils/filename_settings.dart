import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FilenamePrefs {
  static const keySeparator = 'filename_separator'; // 'dash' | 'underscore'

  static final ValueNotifier<String> separatorNotifier =
      ValueNotifier<String>('-');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(keySeparator);
    final cleaned = (saved == '-' || saved == '_') ? saved! : '-';
    separatorNotifier.value = cleaned;
  }

  static Future<void> saveSeparator(String separator) async {
    final cleaned = (separator == '-' || separator == '_') ? separator : '-';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySeparator, cleaned);
    separatorNotifier.value = cleaned;
  }
}
