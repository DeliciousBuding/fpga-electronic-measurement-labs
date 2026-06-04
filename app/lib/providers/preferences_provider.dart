import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class AppPreferences {
  final bool hideBarOnScroll;
  final List<String> bottomNavIds;

  const AppPreferences({
    this.hideBarOnScroll = true,
    this.bottomNavIds = const ['color', 'effects', 'scenes', 'settings'],
  });

  AppPreferences copyWith({bool? hideBarOnScroll, List<String>? bottomNavIds}) =>
      AppPreferences(
          hideBarOnScroll: hideBarOnScroll ?? this.hideBarOnScroll,
          bottomNavIds: bottomNavIds ?? this.bottomNavIds);
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  static const _hideBarKey = 'pref_hide_bar_on_scroll';

  @override
  AppPreferences build() {
    final p = ref.read(sharedPreferencesProvider);
    return AppPreferences(hideBarOnScroll: p.getBool(_hideBarKey) ?? true);
  }

  Future<void> setHideBarOnScroll(bool v) async {
    state = state.copyWith(hideBarOnScroll: v);
    await ref.read(sharedPreferencesProvider).setBool(_hideBarKey, v);
  }
}

final preferencesProvider =
    NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);

class BarVisibilityNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void show() => state = 1.0;
  void hide() => state = 0.0;
}

final barVisibilityProvider =
    NotifierProvider<BarVisibilityNotifier, double>(BarVisibilityNotifier.new);
