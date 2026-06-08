import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../theme/app_design.dart';
import 'shared/ble_widgets.dart';

class SceneTab extends ConsumerStatefulWidget {
  const SceneTab({super.key});

  @override
  ConsumerState<SceneTab> createState() => _SceneTabState();
}

class _SceneTabState extends ConsumerState<SceneTab> {
  Timer? _statusQueryTimer;

  static const _scenes = [
    (Icons.wb_twilight_rounded, 0xFFEF4444, 'sunset', [0xFFFF6B35, 0xFFFFD700]),
    (
      Icons.auto_awesome_rounded,
      0xFF06B6D4,
      'aurora',
      [0xFF00FF87, 0xFF60EFFF],
    ),
    (Icons.nightlife_rounded, 0xFF8B5CF6, 'neon', [0xFFFF00FF, 0xFF00FFFF]),
    (
      Icons.local_fire_department_rounded,
      0xFFF97316,
      'flame',
      [0xFFFF0000, 0xFFFF8C00],
    ),
    (Icons.forest_rounded, 0xFF22C55E, 'forest', [0xFF228B22, 0xFF7CFC00]),
    (Icons.water_drop_rounded, 0xFF38BDF8, 'ocean', [0xFF001F5C, 0xFF00B4D8]),
    (Icons.wb_sunny_rounded, 0xFFFBBF24, 'warmSun', [0xFFFFE4B5, 0xFFFFD700]),
    (Icons.bolt_rounded, 0xFFE879F9, 'lightning', [0xFFE040FB, 0xFF00E5FF]),
  ];

  @override
  void dispose() {
    _statusQueryTimer?.cancel();
    super.dispose();
  }

  String _sceneName(AppLocalizations t, String key) => switch (key) {
    'sunset' => t.sceneSunset,
    'aurora' => t.sceneAurora,
    'neon' => t.sceneNeon,
    'flame' => t.sceneFlame,
    'forest' => t.sceneForest,
    'ocean' => t.sceneOcean,
    'warmSun' => t.sceneWarmSun,
    'lightning' => t.sceneLightning,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final ble = ref.read(bleServiceProvider);
    final sceneSaved = ref.watch(
      deviceProvider.select((state) => state.sceneSaved),
    );
    final activeSceneIndex = ref.watch(
      deviceProvider.select((state) => state.activeSceneIndex),
    );
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.sm;
    final bottomPad =
        MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight +
        AppSpacing.xl;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.sceneTitle), actions: const [BleAction()]),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              topPad,
              AppSpacing.lg,
              0,
            ),
            sliver: SliverList.list(
              children: [
                const SizedBox(height: AppSpacing.xs),
                const BleBanner(),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        t.sceneHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 2.85,
              ),
              delegate: SliverChildBuilderDelegate((context, i) {
                final scene = _scenes[i];
                final name = _sceneName(t, scene.$3);
                final saved = sceneSaved.length > i && sceneSaved[i];
                final active = activeSceneIndex == i;
                return _SceneCard(
                  icon: scene.$1,
                  accent: Color(scene.$2),
                  name: name,
                  gradientColors: scene.$4.map(Color.new).toList(),
                  saved: saved,
                  active: active,
                  onLoad: () {
                    HapticFeedback.selectionClick();
                    ref.read(deviceProvider.notifier).markSceneActive(i);
                    ble.loadScene(i);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.sceneLoaded(name)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    _statusQueryTimer?.cancel();
                    _statusQueryTimer = Timer(
                      const Duration(milliseconds: 300),
                      () => ble.queryStatus(),
                    );
                  },
                  onSave: () {
                    HapticFeedback.mediumImpact();
                    ble.saveScene(i);
                    ref.read(deviceProvider.notifier).markSceneSaved(i);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.sceneSaved(name)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }, childCount: _scenes.length),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.icon,
    required this.accent,
    required this.name,
    required this.gradientColors,
    required this.saved,
    required this.active,
    required this.onLoad,
    required this.onSave,
  });

  final IconData icon;
  final Color accent;
  final String name;
  final List<Color> gradientColors;
  final bool saved;
  final bool active;
  final VoidCallback onLoad;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = active
        ? accent
        : saved
        ? accent.withAlpha(120)
        : cs.outlineVariant.withAlpha(60);
    return Card(
      color: active
          ? accent.withAlpha(24)
          : saved
          ? accent.withAlpha(15)
          : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: borderColor, width: active ? 2 : 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onLoad,
        onLongPress: onSave,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SceneSwatch(
                icon: icon,
                accent: accent,
                gradientColors: gradientColors,
                saved: saved,
                active: active,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: active ? accent : cs.onSurface,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.play_arrow_rounded, size: 18, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SceneSwatch extends StatelessWidget {
  const _SceneSwatch({
    required this.icon,
    required this.accent,
    required this.gradientColors,
    required this.saved,
    required this.active,
  });

  final IconData icon;
  final Color accent;
  final List<Color> gradientColors;
  final bool saved;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Icon(icon, color: Colors.white.withAlpha(225), size: 19),
        ),
        Positioned(
          right: -3,
          top: -3,
          child: AnimatedScale(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            scale: saved && !active ? 1 : 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ),
        Positioned(
          right: -4,
          bottom: -4,
          child: AnimatedScale(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            scale: active ? 1 : 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
