import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import 'shared/ble_widgets.dart';
import 'shared/sliders.dart';

class EffectTab extends ConsumerStatefulWidget {
  const EffectTab({super.key});
  @override
  ConsumerState<EffectTab> createState() => _EffectTabState();
}

class _EffectTabState extends ConsumerState<EffectTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncAnimation();
      ref.listenManual(deviceProvider.select((s) => s.mode), (prev, next) {
        _syncAnimation(next);
      });
    });
  }

  void _syncAnimation([int? mode]) {
    final m = mode ?? ref.read(deviceProvider).mode;
    if (m >= 1 && m <= 3 && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if ((m == 0 || m == 4) && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    final activeMode = s.mode;

    final effects = [
      _EffectDef(0, t.modeStatic, Icons.light_mode_rounded, t.descStatic, const Color(0xFFFFD93D)),
      _EffectDef(1, t.modeBreath, Icons.air_rounded, t.descBreath, const Color(0xFF06B6D4)),
      _EffectDef(2, t.modeFlow, Icons.waves_rounded, t.descFlow, const Color(0xFF3B82F6)),
      _EffectDef(3, t.modeGradient, Icons.gradient_rounded, t.descGradient, const Color(0xFF8B5CF6)),
      _EffectDef(4, t.modeMusic, Icons.music_note_rounded, t.descMusic, const Color(0xFFEC4899), wip: true),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          title: Text(t.navEffect),
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
          for (final e in effects)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EffectCard(
                def: e,
                selected: activeMode == e.mode,
                ctrl: activeMode == e.mode ? _ctrl : null,
                onTap: e.wip
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        ref.read(deviceProvider.notifier).setMode(e.mode);
                        ble.setMode(e.mode);
                      },
              ),
            ),
          if (activeMode == 2 || activeMode == 3)
            SliderCard(
                label: activeMode == 2 ? t.flowSpeed : t.gradientSpeed,
                icon: Icons.speed_rounded,
                value: s.flowSpeed.toDouble(),
                min: 1,
                max: 255,
                color: activeMode == 2
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFF8B5CF6),
                onChanged: (v) {
                  final iv = v.round();
                  ref.read(deviceProvider.notifier).setFlowSpeed(iv);
                  ble.setFlowSpeedThrottled(iv);
                }),
          if (activeMode == 1)
            SliderCard(
                label: t.breathPeriod,
                icon: Icons.timelapse_rounded,
                value: s.breathPeriod.toDouble(),
                min: 1,
                max: 255,
                color: const Color(0xFF06B6D4),
                onChanged: (v) {
                  final iv = v.round();
                  ref.read(deviceProvider.notifier).setBreathPeriod(iv);
                  ble.setBreathPeriodThrottled(iv);
                }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EffectDef {
  final int mode;
  final String name, desc;
  final IconData icon;
  final Color color;
  final bool wip;
  const _EffectDef(this.mode, this.name, this.icon, this.desc, this.color, {this.wip = false});
}

class _EffectCard extends StatelessWidget {
  final _EffectDef def;
  final bool selected;
  final AnimationController? ctrl;
  final VoidCallback? onTap;
  const _EffectCard({required this.def, required this.selected, required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide(color: def.color.withAlpha(120), width: 1.5)
              : BorderSide(color: cs.outlineVariant.withAlpha(60))),
      color: def.wip
          ? cs.surfaceContainerLowest
          : (selected ? cs.primaryContainer : cs.surfaceContainerLow),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            ctrl != null
                ? _AnimatedPreview(ctrl: ctrl!, mode: def.mode, color: def.color)
                : _StaticPreview(icon: def.icon, color: def.color),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: def.wip
                          ? cs.onSurfaceVariant.withAlpha(80)
                          : (selected ? cs.onPrimaryContainer : cs.onSurface))),
              const SizedBox(height: 2),
              Text(def.desc,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: def.wip
                          ? cs.onSurfaceVariant.withAlpha(60)
                          : (selected
                              ? cs.onPrimaryContainer.withAlpha(180)
                              : cs.onSurfaceVariant))),
            ])),
            if (def.wip)
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: cs.outlineVariant.withAlpha(30)),
                  child: Text(t.wip,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant.withAlpha(100))))
            else if (selected)
              Container(
                  width: 28,
                  height: 28,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, color: def.color),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 18)),
          ]),
        ),
      ),
    );
  }
}

// Only instantiated for the active effect — single animation
class _AnimatedPreview extends StatelessWidget {
  final AnimationController ctrl;
  final int mode;
  final Color color;
  const _AnimatedPreview({required this.ctrl, required this.mode, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withAlpha(30)),
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: List.generate(4, (i) {
            final alpha = switch (mode) {
              0 => 1.0,
              1 => 0.5 + 0.5 * math.sin(ctrl.value * 2 * math.pi),
              2 => () { final pos = ctrl.value * 4; final d = (pos - i).abs(); return (1.0 - d).clamp(0.2, 1.0); }(),
              _ => 1.0,
            };
            final dotColor = mode == 3
                ? HSVColor.fromAHSV(1.0, (ctrl.value * 360 + i * 30) % 360, 1.0, 1.0).toColor()
                : color;
            final f = mode == 3 ? 1.0 : alpha.clamp(0.1, 1.0);
            return Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromARGB((f * 255).round(), (dotColor.r * 255).round(), (dotColor.g * 255).round(), (dotColor.b * 255).round()),
                boxShadow: f > 0.5 ? [BoxShadow(color: dotColor.withAlpha((f * 60).round()), blurRadius: 4)] : null,
              ),
            );
          })),
        ),
      ),
    );
  }
}

class _StaticPreview extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _StaticPreview({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: cs.surfaceContainerLowest),
      child: Icon(icon, color: color.withAlpha(100), size: 24),
    );
  }
}
