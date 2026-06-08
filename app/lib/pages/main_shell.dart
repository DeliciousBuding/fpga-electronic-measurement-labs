import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../providers/preferences_provider.dart';
import '../theme/app_design.dart';
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
  static const double _hideScrollThreshold = 36;
  static const double _showScrollThreshold = 18;
  static const double _topRevealExtent = 6;

  late final PageController _pageCtrl;
  int _index = 0;
  StreamSubscription<BleEvent>? _bleSub;
  double _barScrollAccumulator = 0;

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
        ref
            .read(deviceProvider.notifier)
            .updateFromStatus(
              event.mode,
              event.r,
              event.g,
              event.b,
              event.brightness,
            );
      } else if (event is BleAckEvent && !event.success) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.bleCmdFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (event is BleConnectionEvent &&
          event.connected &&
          event.name != null) {
        final t = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.bleConnected(event.name!)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (!ref.read(preferencesProvider).hideBarOnScroll) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    final visibility = ref.read(barVisibilityProvider);
    final bar = ref.read(barVisibilityProvider.notifier);

    if (notification.metrics.pixels <=
        notification.metrics.minScrollExtent + _topRevealExtent) {
      _barScrollAccumulator = 0;
      if (visibility != 1.0) bar.show();
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta;
      if (delta == null || delta.abs() < 0.5) return false;

      if (delta > 0) {
        if (_barScrollAccumulator < 0) _barScrollAccumulator = 0;
        _barScrollAccumulator += delta;
        if (_barScrollAccumulator < _hideScrollThreshold) return false;
        if (visibility != 0.0) bar.hide();
      } else {
        if (_barScrollAccumulator > 0) _barScrollAccumulator = 0;
        _barScrollAccumulator += delta;
        if (_barScrollAccumulator > -_showScrollThreshold) return false;
        if (visibility != 1.0) bar.show();
      }
      _barScrollAccumulator = 0;
    } else if (notification is ScrollEndNotification) {
      _barScrollAccumulator = 0;
    }

    return false;
  }

  void _showBarIfHidden() {
    if (ref.read(barVisibilityProvider) != 1.0) {
      ref.read(barVisibilityProvider.notifier).show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideBar = ref.watch(
      preferencesProvider.select((p) => p.hideBarOnScroll),
    );
    final barVis = ref.watch(barVisibilityProvider);
    final visibility = hideBar ? barVis : 1.0;
    final barHidden = visibility == 0.0;
    final barDuration = AppMotion.duration(context, AppMotion.normal);
    final t = AppLocalizations.of(context)!;
    final items = [
      _BottomNavItem(
        label: t.navLed,
        icon: Icons.lightbulb_outline_rounded,
        selectedIcon: Icons.lightbulb_rounded,
      ),
      _BottomNavItem(
        label: t.navEffect,
        icon: Icons.auto_awesome_rounded,
        selectedIcon: Icons.auto_awesome_rounded,
      ),
      _BottomNavItem(
        label: t.navScene,
        icon: Icons.bookmark_border_rounded,
        selectedIcon: Icons.bookmark_rounded,
      ),
      _BottomNavItem(
        label: t.navSettings,
        icon: Icons.tune_rounded,
        selectedIcon: Icons.tune_rounded,
      ),
    ];

    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (i) {
            _showBarIfHidden();
            setState(() => _index = i);
          },
          children: [
            _ShellPage(
              index: 0,
              currentIndex: _index,
              child: const ColorTab(key: PageStorageKey('tab-color')),
            ),
            _ShellPage(
              index: 1,
              currentIndex: _index,
              child: const EffectTab(key: PageStorageKey('tab-effect')),
            ),
            _ShellPage(
              index: 2,
              currentIndex: _index,
              child: const SceneTab(key: PageStorageKey('tab-scene')),
            ),
            _ShellPage(
              index: 3,
              currentIndex: _index,
              child: const SettingsPage(key: PageStorageKey('tab-settings')),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: IgnorePointer(
          ignoring: barHidden,
          child: AnimatedSlide(
            offset: barHidden ? const Offset(0, 1) : Offset.zero,
            duration: barDuration,
            curve: AppMotion.curve(context, AppMotion.emphasized),
            child: AnimatedOpacity(
              opacity: visibility,
              duration: barDuration,
              curve: AppMotion.curve(context, AppMotion.standard),
              child: RepaintBoundary(
                child: _IconBottomBar(
                  selectedIndex: _index,
                  items: items,
                  onSelected: (i) {
                    _showBarIfHidden();
                    if (AppMotion.reduced(context)) {
                      _pageCtrl.jumpToPage(i);
                    } else {
                      _pageCtrl.animateToPage(
                        i,
                        duration: AppMotion.duration(context, AppMotion.page),
                        curve: AppMotion.curve(context, AppMotion.emphasized),
                      );
                    }
                    setState(() => _index = i);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBottomBar extends StatelessWidget {
  const _IconBottomBar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_BottomNavItem> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(246),
        border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(70))),
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: bottomInset > 0 ? AppSpacing.xs : AppSpacing.sm,
        ),
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              return _IconBottomBarButton(
                item: item,
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _IconBottomBarButton extends StatelessWidget {
  const _IconBottomBarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _BottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = ExcludeSemantics(
      child: AnimatedScale(
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.curve(context, AppMotion.standard),
        scale: selected ? 1.08 : 1.0,
        child: Icon(
          selected ? item.selectedIcon : item.icon,
          size: selected ? 26 : 24,
          color: selected ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        onTap: onTap,
        child: FocusableActionDetector(
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                onTap();
                return null;
              },
            ),
          },
          mouseCursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(width: 50, height: 50, child: Center(child: icon)),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _ShellPage extends StatelessWidget {
  const _ShellPage({
    required this.index,
    required this.currentIndex,
    required this.child,
  });

  final int index;
  final int currentIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(enabled: index == currentIndex, child: child);
  }
}
