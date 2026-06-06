import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import 'shared/ble_widgets.dart';

class SceneTab extends ConsumerWidget {
  const SceneTab({super.key});

  static const _scenes = [
    (Icons.wb_twilight_rounded, 0xFFEF4444, 'sunset', [0xFFFF6B35, 0xFFFFD700]),
    (Icons.auto_awesome_rounded, 0xFF06B6D4, 'aurora', [0xFF00FF87, 0xFF60EFFF]),
    (Icons.nightlife_rounded, 0xFF8B5CF6, 'neon', [0xFFFF00FF, 0xFF00FFFF]),
    (Icons.local_fire_department_rounded, 0xFFF97316, 'flame', [0xFFFF0000, 0xFFFF8C00]),
    (Icons.forest_rounded, 0xFF22C55E, 'forest', [0xFF228B22, 0xFF7CFC00]),
    (Icons.water_drop_rounded, 0xFF38BDF8, 'ocean', [0xFF001F5C, 0xFF00B4D8]),
    (Icons.wb_sunny_rounded, 0xFFFBBF24, 'warmSun', [0xFFFFE4B5, 0xFFFFD700]),
    (Icons.bolt_rounded, 0xFFE879F9, 'lightning', [0xFFE040FB, 0xFF00E5FF]),
  ];

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
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final s = ref.watch(deviceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          title: Text(t.sceneTitle),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          actions: const [BleAction()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: [
          const SizedBox(height: 4),
          const BleBanner(),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(t.sceneHint,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant))
          ]),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.15),
            itemCount: _scenes.length,
            itemBuilder: (_, i) {
              final sc = _scenes[i];
              final accent = Color(sc.$2);
              final name = _sceneName(t, sc.$3);
              final gradientColors = sc.$4.map(Color.new).toList();
              final saved = s.sceneSaved.length > i && s.sceneSaved[i];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: saved
                        ? BorderSide(color: accent.withAlpha(120), width: 1.5)
                        : BorderSide(color: cs.outlineVariant.withAlpha(60))),
                color: saved ? accent.withAlpha(15) : cs.surfaceContainerLow,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ble.loadScene(i);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(t.sceneLoaded(name)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating));
                    Future.delayed(
                        const Duration(milliseconds: 300), () => ble.queryStatus());
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    ble.saveScene(i);
                    ref.read(deviceProvider.notifier).markSceneSaved(i);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(t.sceneSaved(name)),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(clipBehavior: Clip.none, children: [
                            Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                        colors: gradientColors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight)),
                                child: Icon(sc.$1,
                                    color: Colors.white.withAlpha(220), size: 24)),
                            if (saved)
                              Positioned(
                                  right: -3,
                                  top: -3,
                                  child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: accent,
                                          border: Border.all(
                                              color: Colors.white, width: 1.5)),
                                      child: const Icon(Icons.check_rounded,
                                          color: Colors.white, size: 11))),
                          ]),
                          const SizedBox(height: 8),
                          Text(name,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                        ]),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
