import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

Future<bool> isDark() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getBool("theme") ?? false;
}

Future<void> setTheme(bool isDark) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  prefs.setBool("theme", !isDark);
}

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light) {
    onInitialThemeSetEvent();
  }

  onInitialThemeSetEvent() async {
    final bool hasDarkTheme = await isDark();
    if (hasDarkTheme) {
      value = ThemeMode.dark;
    } else {
      value = ThemeMode.light;
    }
  }

  void onThemeSwitchEvent() {
    final isDark = value == ThemeMode.dark;
    value = (isDark ? ThemeMode.light : ThemeMode.dark);
    setTheme(isDark);
  }
}
