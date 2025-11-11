import 'package:flutter/foundation.dart';

class TabNavigationModel extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void jumpTo(int newIndex) {
    if (newIndex == _index) return;
    _index = newIndex;
    notifyListeners();
  }
}
