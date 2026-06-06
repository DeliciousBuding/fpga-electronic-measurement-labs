import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../providers/preferences_provider.dart';
import 'color_tab.dart';
import 'effect_tab.dart';
import 'scene_tab.dart';
import 'settings_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final PageController _pageCtrl;
  int _index = 0;
  StreamSubscription<BleEvent>? _bleSub;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupBleListener());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _bleSub?.cancel();
    super.dispose();
  }

  void _setupBleListener() {
    final ble = ref.read(bleServiceProvider);
    _bleSub = ble.events.listen((event) {
      if (!mounted) return;
      if (event is BleStatusEvent) {
        ref.read(deviceProvider.notifier).updateFromStatus(
              event.mode, event.r, event.g, event.b, event.brightness,
            );
      } else if (event is BleAckEvent && !event.success) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.bleCmdFailed),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } else if (event is BleConnectionEvent &&
          event.connected &&
          event.name != null) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(t.bleConnected(event.name!)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hideBar =
        ref.watch(preferencesProvider.select((p) => p.hideBarOnScroll));
    final barVis = ref.watch(barVisibilityProvider);
    final visibility = hideBar ? barVis : 1.0;
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: PageView(
        controller: _pageCtrl,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) {
          ref.read(barVisibilityProvider.notifier).show();
          setState(() => _index = i);
        },
        children: const [ColorTab(), EffectTab(), SceneTab(), SettingsPage()],
      ),
      bottomNavigationBar: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visibility,
          child: Opacity(
            opacity: visibility,
            child: NavigationBar(
              selectedIndex: _index,
              animationDuration: const Duration(milliseconds: 400),
              onDestinationSelected: (i) {
                ref.read(barVisibilityProvider.notifier).show();
                _pageCtrl.animateToPage(i,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutCubic);
                setState(() => _index = i);
              },
              destinations: [
                NavigationDestination(
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 22),
                    selectedIcon: const Icon(Icons.lightbulb_rounded, size: 22),
                    label: t.navLed),
                NavigationDestination(
                    icon: const Icon(Icons.auto_awesome_rounded, size: 22),
                    selectedIcon: const Icon(Icons.auto_awesome_rounded, size: 22),
                    label: t.navEffect),
                NavigationDestination(
                    icon: const Icon(Icons.bookmark_border_rounded, size: 22),
                    selectedIcon: const Icon(Icons.bookmark_rounded, size: 22),
                    label: t.navScene),
                NavigationDestination(
                    icon: const Icon(Icons.tune_rounded, size: 22),
                    selectedIcon: const Icon(Icons.tune_rounded, size: 22),
                    label: t.navSettings),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
