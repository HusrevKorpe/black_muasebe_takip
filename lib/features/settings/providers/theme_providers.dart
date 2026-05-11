import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefKey = 'app_theme_mode';

ThemeMode _decode(String? raw) {
  switch (raw) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
}

String _encode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.light:
      return 'light';
    case ThemeMode.system:
      return 'system';
  }
}

Future<ThemeMode> loadInitialThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  return _decode(prefs.getString(_themePrefKey));
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  throw UnimplementedError(
    'themeModeProvider main()de override edilmeli (initial mode ile).',
  );
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, _encode(mode));
  }

  Future<void> toggleDark(bool dark) =>
      setMode(dark ? ThemeMode.dark : ThemeMode.light);
}
