import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

class LocaleNotifier extends Notifier<Locale?> {
  static const _k = 'pref_locale';

  @override
  Locale? build() {
    final p = ref.read(sharedPreferencesProvider);
    final s = p.getString(_k);
    if (s == null || s == 'system') return null;
    final parts = s.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }

  Future<void> set(Locale? l) async {
    state = l;
    final p = ref.read(sharedPreferencesProvider);
    if (l == null) {
      await p.setString(_k, 'system');
    } else {
      final code = l.countryCode != null
          ? '${l.languageCode}_${l.countryCode}'
          : l.languageCode;
      await p.setString(_k, code);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);
