import 'package:flutter/material.dart';

class LanguageNotifier extends ChangeNotifier {
  bool isHindi = false;

  void toggleLanguage(bool value) {
    isHindi = value;
    notifyListeners();
  }
}
