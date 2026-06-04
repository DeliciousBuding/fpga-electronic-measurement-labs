import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'providers/ble_provider.dart';
import 'pages/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const RgbControllerApp(),
    ),
  );
}

class RgbControllerApp extends ConsumerWidget {
  const RgbControllerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (themeState.useDynamicColor &&
            lightDynamic != null &&
            darkDynamic != null) {
          lightScheme = ColorScheme.fromSeed(
            seedColor: lightDynamic.primary,
            brightness: Brightness.light,
            dynamicSchemeVariant: themeState.schemeVariant,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: darkDynamic.primary,
            brightness: Brightness.dark,
            dynamicSchemeVariant: themeState.schemeVariant,
          );
        } else {
          lightScheme = ColorScheme.fromSeed(
            seedColor: themeState.seedColor,
            brightness: Brightness.light,
            dynamicSchemeVariant: themeState.schemeVariant,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: themeState.seedColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: themeState.schemeVariant,
          );
        }

        return MaterialApp(
          title: 'RGB Controller',
          debugShowCheckedModeBanner: false,
          themeMode: themeState.mode,
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            fontFamily: themeState.fontFamilyName,
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: lightScheme.surfaceContainerLow,
              margin: EdgeInsets.zero,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            fontFamily: themeState.fontFamilyName,
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              color: darkScheme.surfaceContainerLow,
              margin: EdgeInsets.zero,
            ),
          ),
          builder: (context, child) {
            final brightness = Theme.of(context).brightness;
            final iconBrightness =
                brightness == Brightness.light ? Brightness.dark : Brightness.light;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: iconBrightness,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: iconBrightness,
                systemNavigationBarDividerColor: Colors.transparent.withAlpha(1),
                systemNavigationBarContrastEnforced: false,
              ),
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

class _BLEGateState extends ConsumerState<BLEGate> {
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initBLE();
  }

  Future<void> _initBLE() async {
    try {
      await ref.read(bleServiceProvider).init();
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('BLE 初始化失败:\n$_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _initBLE, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const MainShell();
  }
}
