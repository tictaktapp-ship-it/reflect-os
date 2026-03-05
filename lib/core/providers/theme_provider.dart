import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('theme_mode') ?? 'light';
      if (mounted) {
        state = value == 'light' ? ThemeMode.light : ThemeMode.dark;
      }
    } catch (_) {
      // keep default light
    }
  }

  Future<void> toggle() async {
    try {
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', state == ThemeMode.light ? 'light' : 'dark');
    } catch (_) {}
  }
}
