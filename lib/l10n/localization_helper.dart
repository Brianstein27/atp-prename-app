import 'package:flutter/material.dart';

extension LocalizationHelper on BuildContext {
  bool get isGermanLocale =>
      Localizations.localeOf(this).languageCode?.toLowerCase() == 'de';

  String tr({required String de, required String en}) {
    return isGermanLocale ? de : en;
  }
}
