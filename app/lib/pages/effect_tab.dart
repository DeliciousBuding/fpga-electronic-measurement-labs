import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../theme/app_design.dart';
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
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.effectPreviewCycle,
    );
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
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.sm;
    final bottomPad =
        MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight +
        AppSpacing.xl;

    final activeMode = ref.watch(deviceProvider.select((s) => s.mode));
    final flowSpeed = ref.watch(deviceProvider.select((s) => s.flowSpeed));
    final breathPeriod = ref.watch(
      deviceProvider.select((s) => s.breathPeriod),
    );

    final effects = [
      _EffectDef(
        0,
        t.modeStatic,
        Icons.light_mode_rounded,
        t.descStatic,
        const Color(0xFFFFD93D),
      ),
      _EffectDef(
        1,
        t.modeBreath,
        Icons.air_rounded,
        t.descBreath,
        const Color(0xFF06B6D4),
      ),
      _EffectDef(
        2,
        t.modeFlow,
        Icons.waves_rounded,
        t.descFlow,
        const Color(0xFF3B82F6),
      ),
      _EffectDef(
        3,
        t.modeGradient,
        Icons.gradient_rounded,
        t.descGradient,
        const Color(0xFF8B5CF6),
      ),
      _EffectDef(
        4,
        t.modeMusic,
        Icons.music_note_rounded,
        t.descMusic,
        const Color(0xFFEC4899),
        wip: true,
      ),
    ];
    final activeEffect = effects.firstWhere(
      (effect) => effect.mode == activeMode,
      orElse: () => effects.first,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.navEffect), actions: const [BleAction()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPad,
          AppSpacing.lg,
          bottomPad,
        ),
        children: [
          const SizedBox(height: AppSpacing.xs),
          const BleBanner(),
          const SizedBox(height: AppSpacing.sm),
          _EffectModeSelector(
            effects: effects,
            activeMode: activeMode,
            onSelect: (effect) {
              if (effect.wip || effect.mode == activeMode) return;
              HapticFeedback.selectionClick();
              ref.read(deviceProvider.notifier).setMode(effect.mode);
              ble.setMode(effect.mode);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _EffectPreviewPanel(
            def: activeEffect,
            ctrl: activeMode >= 1 && activeMode <= 3 ? _ctrl : null,
          ),
          const SizedBox(height: AppSpacing.md),
          if (activeMode == 2 || activeMode == 3)
            SliderCard(
              label: activeMode == 2 ? t.flowSpeed : t.gradientSpeed,
              icon: Icons.speed_rounded,
              value: flowSpeed.toDouble(),
              min: 1,
              max: 255,
              color: activeMode == 2
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF8B5CF6),
              onChanged: (v) {
                final iv = v.round();
                ref.read(deviceProvider.notifier).setFlowSpeed(iv);
                ble.setFlowSpeedThrottled(iv);
              },
            ),
          if (activeMode == 1)
            SliderCard(
              label: t.breathPeriod,
              icon: Icons.timelapse_rounded,
              value: breathPeriod.toDouble(),
              min: 1,
              max: 255,
              color: const Color(0xFF06B6D4),
              onChanged: (v) {
                final iv = v.round();
                ref.read(deviceProvider.notifier).setBreathPeriod(iv);
                ble.setBreathPeriodThrottled(iv);
              },
            ),
          const SizedBox(height: AppSpacing.xxl),
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
  const _EffectDef(
    this.mode,
    this.name,
    this.icon,
    this.desc,
    this.color, {
    this.wip = false,
  });
}

class _EffectModeSelector extends StatelessWidget {
  const _EffectModeSelector({
    required this.effects,
    required this.activeMode,
    required this.onSelect,
  });

  final List<_EffectDef> effects;
  final int activeMode;
  final ValueChanged<_EffectDef> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: cs.outlineVariant.withAlpha(55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: effects
              .map(
                (effect) => _EffectModeChip(
                  def: effect,
                  selected: activeMode == effect.mode,
                  wipLabel: t.wip,
                  onTap: effect.wip ? null : () => onSelect(effect),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _EffectModeChip extends StatelessWidget {
  const _EffectModeChip({
    required this.def,
    required this.selected,
    required this.wipLabel,
    required this.onTap,
  });

  final _EffectDef def;
  final bool selected;
  final String wipLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: def.wip
          ? cs.onSurfaceVariant.withAlpha(95)
          : (selected ? cs.onPrimaryContainer : cs.onSurfaceVariant),
    );
    final chip = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: 44,
      constraints: const BoxConstraints(minWidth: 92),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        color: selected
            ? def.color.withAlpha(34)
            : cs.surfaceContainerHighest.withAlpha(def.wip ? 65 : 120),
        border: Border.all(
          color: selected ? def.color.withAlpha(145) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  def.icon,
                  size: 18,
                  color: def.wip
                      ? cs.onSurfaceVariant.withAlpha(85)
                      : (selected ? def.color : cs.onSurfaceVariant),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(def.name, style: labelStyle),
                if (def.wip) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    wipLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withAlpha(90),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: def.wip ? def.desc : def.name,
      child: Semantics(
        button: true,
        enabled: !def.wip,
        selected: selected,
        label: def.wip ? '${def.name}, $wipLabel' : def.name,
        child: chip,
      ),
    );
  }
}

class _EffectPreviewPanel extends StatelessWidget {
  const _EffectPreviewPanel({required this.def, required this.ctrl});

  final _EffectDef def;
  final AnimationController? ctrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.emphasized,
      switchOutCurve: AppMotion.standard,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: Card(
        key: ValueKey(def.mode),
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: def.color.withAlpha(85)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ctrl != null
                      ? _AnimatedPreview(
                          ctrl: ctrl!,
                          mode: def.mode,
                          color: def.color,
                          size: 76,
                        )
                      : _StaticPreview(
                          icon: def.icon,
                          color: def.color,
                          size: 76,
                        ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          def.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          def.desc,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Only instantiated for the active effect: one animated painter per page.
class _AnimatedPreview extends StatelessWidget {
  final AnimationController ctrl;
  final int mode;
  final Color color;
  final double size;
  const _AnimatedPreview({
    required this.ctrl,
    required this.mode,
    required this.color,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _EffectPreviewPainter(
              progress: ctrl.value,
              mode: mode,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _EffectPreviewPainter extends CustomPainter {
  const _EffectPreviewPainter({
    required this.progress,
    required this.mode,
    required this.color,
  });

  final double progress;
  final int mode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(10),
    );
    canvas.drawRRect(bg, Paint()..color = color.withAlpha(30));

    const count = 4;
    const dotRadius = 4.0;
    const gap = 3.0;
    final totalWidth = count * dotRadius * 2 + (count - 1) * gap;
    final startX = (size.width - totalWidth) / 2 + dotRadius;
    final cy = size.height / 2;

    for (var i = 0; i < count; i++) {
      final alpha = switch (mode) {
        0 => 1.0,
        1 => 0.5 + 0.5 * math.sin(progress * 2 * math.pi),
        2 => () {
          final pos = progress * count;
          final d = (pos - i).abs();
          return (1.0 - d).clamp(0.2, 1.0);
        }(),
        _ => 1.0,
      };
      final dotColor = mode == 3
          ? HSVColor.fromAHSV(
              1.0,
              (progress * 360 + i * 30) % 360,
              1.0,
              1.0,
            ).toColor()
          : color;
      final f = mode == 3 ? 1.0 : alpha.clamp(0.1, 1.0);
      final center = Offset(startX + i * (dotRadius * 2 + gap), cy);
      if (f > 0.5) {
        canvas.drawCircle(
          center,
          dotRadius + 3,
          Paint()..color = dotColor.withAlpha((f * 24).round()),
        );
      }
      canvas.drawCircle(
        center,
        dotRadius,
        Paint()
          ..color = Color.fromARGB(
            (f * 255).round(),
            (dotColor.r * 255).round(),
            (dotColor.g * 255).round(),
            (dotColor.b * 255).round(),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPreviewPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.mode != mode ||
        oldDelegate.color != color;
  }
}

class _StaticPreview extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _StaticPreview({
    required this.icon,
    required this.color,
    this.size = 44,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        color: cs.surfaceContainerLowest,
      ),
      child: Icon(icon, color: color.withAlpha(120), size: size * 0.48),
    );
  }
}
