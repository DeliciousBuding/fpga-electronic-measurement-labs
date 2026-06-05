import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'providers/theme_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/ble_provider.dart';
import 'pages/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const RgbControllerApp(),
  ));
}

class RgbControllerApp extends ConsumerWidget {
  const RgbControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme, darkScheme;
        if (themeState.useDynamicColor && lightDynamic != null && darkDynamic != null) {
          lightScheme = ColorScheme.fromSeed(seedColor: lightDynamic.primary, brightness: Brightness.light, dynamicSchemeVariant: themeState.schemeVariant);
          darkScheme = ColorScheme.fromSeed(seedColor: darkDynamic.primary, brightness: Brightness.dark, dynamicSchemeVariant: themeState.schemeVariant);
        } else {
          lightScheme = ColorScheme.fromSeed(seedColor: themeState.seedColor, brightness: Brightness.light, dynamicSchemeVariant: themeState.schemeVariant);
          darkScheme = ColorScheme.fromSeed(seedColor: themeState.seedColor, brightness: Brightness.dark, dynamicSchemeVariant: themeState.schemeVariant);
        }
        return MaterialApp(
          title: 'RGB Controller',
          debugShowCheckedModeBanner: false,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          themeMode: themeState.mode,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            fontFamily: themeState.fontFamilyName,
            pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
            cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: lightScheme.surfaceContainerLow, margin: EdgeInsets.zero),
            navigationBarTheme: NavigationBarThemeData(indicatorShape: const StadiumBorder(), indicatorColor: lightScheme.secondaryContainer, labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected),
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            fontFamily: themeState.fontFamilyName,
            pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: CupertinoPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
            cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: darkScheme.surfaceContainerLow, margin: EdgeInsets.zero),
            navigationBarTheme: NavigationBarThemeData(indicatorShape: const StadiumBorder(), indicatorColor: darkScheme.secondaryContainer, labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected),
          ),
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final iconBrightness = brightness == Brightness.light ? Brightness.dark : Brightness.light;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: iconBrightness, systemNavigationBarColor: Colors.transparent, systemNavigationBarIconBrightness: iconBrightness, systemNavigationBarDividerColor: Colors.transparent.withAlpha(1), systemNavigationBarContrastEnforced: false),
              child: child!,
            );
          },
          home: const BLEGate(),
        );
      },
    );
  }
}

class BLEGate extends ConsumerStatefulWidget {
  const BLEGate({super.key});
  @override
  ConsumerState<BLEGate> createState() => _BLEGateState();
}

class _BLEGateState extends ConsumerState<BLEGate> with SingleTickerProviderStateMixin {
  bool _ready = false;
  late AnimationController _splashCtrl;
  late Animation<double> _splashFade;

  @override
  void initState() {
    super.initState();
    _splashCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _splashFade = CurvedAnimation(parent: _splashCtrl, curve: Curves.easeOut);
    _splashCtrl.forward();
    _initBLE();
  }

  Future<void> _initBLE() async {
    try {
      await ref.read(bleServiceProvider).init().timeout(const Duration(seconds: 10));
    } catch (_) {
      // BLE init failure is non-fatal — user can still use the app
      // and will see the BLE-off banner with connect button
    }
    if (mounted) {
      await _splashCtrl.reverse();
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() { _splashCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(color: cs.surface),
          child: Center(
            child: FadeTransition(
              opacity: _splashFade,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.primaryContainer, boxShadow: [BoxShadow(color: cs.primary.withAlpha(60), blurRadius: 32, spreadRadius: 8)]),
                  child: Icon(Icons.bluetooth_rounded, size: 40, color: cs.primary),
                ),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(context)!.appTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 32),
                SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)),
              ]),
            ),
          ),
        ),
      );
    }
    return const MainShell();
  }
}
