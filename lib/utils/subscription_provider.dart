import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionProvider extends ChangeNotifier {
  static const _prefsKey = 'is_premium_user';

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    if (_isPremium == value) return;
    _isPremium = value;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
