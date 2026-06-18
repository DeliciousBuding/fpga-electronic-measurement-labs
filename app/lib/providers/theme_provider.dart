import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override');
});

enum AppFontFamily { system, miSans }

class ThemeState {
  final ThemeMode mode;
  final Color seedColor;
  final bool useDynamicColor;
  final AppFontFamily fontFamily;
  final DynamicSchemeVariant schemeVariant;

  const ThemeState({
    required this.mode,
    required this.seedColor,
    this.useDynamicColor = true,
    this.fontFamily = AppFontFamily.system,
    this.schemeVariant = DynamicSchemeVariant.tonalSpot,
  });

  String? get fontFamilyName =>
      fontFamily == AppFontFamily.miSans ? 'MiSans' : null;

  ThemeState copyWith({
    ThemeMode? mode,
    Color? seedColor,
    bool? useDynamicColor,
    AppFontFamily? fontFamily,
    DynamicSchemeVariant? schemeVariant,
  }) => ThemeState(
    mode: mode ?? this.mode,
    seedColor: seedColor ?? this.seedColor,
    useDynamicColor: useDynamicColor ?? this.useDynamicColor,
    fontFamily: fontFamily ?? this.fontFamily,
    schemeVariant: schemeVariant ?? this.schemeVariant,
  );
}

class ThemeNotifier extends Notifier<ThemeState> {
  static const _kMode = 'theme_mode';
  static const _kColor = 'seed_color';

  @override
  ThemeState build() => _load(ref.read(sharedPreferencesProvider));

  static ThemeState _load(SharedPreferences p) {
    final m = p.getString(_kMode);
    ThemeMode mode = ThemeMode.system;
    if (m == 'light') mode = ThemeMode.light;
    if (m == 'dark') mode = ThemeMode.dark;
    final c = p.getInt(_kColor);
    return ThemeState(
      mode: mode,
      seedColor: c != null ? Color(c) : const Color(0xFF6750A4),
    );
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = state.copyWith(mode: m);
    final v = m == ThemeMode.light
        ? 'light'
        : m == ThemeMode.dark
        ? 'dark'
        : 'system';
    await ref.read(sharedPreferencesProvider).setString(_kMode, v);
  }

  Future<void> setSeedColor(Color c) async {
    state = state.copyWith(seedColor: c, useDynamicColor: false);
    await ref.read(sharedPreferencesProvider).setInt(_kColor, c.toARGB32());
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
