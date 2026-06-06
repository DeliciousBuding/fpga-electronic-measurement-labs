import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../utils/colors.dart';
import 'shared/ble_widgets.dart';
import 'shared/sliders.dart';

class ColorTab extends ConsumerWidget {
  const ColorTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final color = Color.fromARGB(255, s.r, s.g, s.b);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          title: Text(t.appTitle),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          actions: const [BleAction()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: [
          const SizedBox(height: 4),
          const BleBanner(),
          const SizedBox(height: 16),
          _ColorHero(color: color, mode: s.mode, brightness: s.brightness),
          const SizedBox(height: 20),
          SliderCard(
              label: t.brightness,
              icon: Icons.brightness_6_rounded,
              value: s.brightness.toDouble(),
              min: 0,
              max: 255,
              color: cs.primary,
              onChanged: (v) {
                final iv = v.round();
                ref.read(deviceProvider.notifier).setBrightness(iv);
                ble.setBrightnessThrottled(iv);
              }),
          const SizedBox(height: 12),
          _RgbSliders(r: s.r, g: s.g, b: s.b, ble: ble, ref: ref),
          const SizedBox(height: 12),
          _PresetColors(
              r: s.r, g: s.g, b: s.b,
              onPick: (r, g, b) {
                HapticFeedback.selectionClick();
                ref.read(deviceProvider.notifier).setColor(r, g, b);
                ble.setColor(r, g, b);
              }),
          const SizedBox(height: 12),
          _QuickActions(onColor: (r, g, b) {
            HapticFeedback.lightImpact();
            ref.read(deviceProvider.notifier).setColor(r, g, b);
            ble.setColor(r, g, b);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Color Hero (orb + hex + led dots + mode badges) ───

class _ColorHero extends StatefulWidget {
  final Color color;
  final int mode, brightness;
  const _ColorHero(
      {required this.color, required this.mode, required this.brightness});
  @override
  State<_ColorHero> createState() => _ColorHeroState();
}

class _ColorHeroState extends State<_ColorHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _ColorHero old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _syncAnimation();
  }

  void _syncAnimation() {
    final animated = widget.mode >= 1 && widget.mode <= 3;
    if (animated && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!animated && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bf = widget.brightness / 255.0;
    final base = widget.color;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(children: [
          // ── Animated orb (only this rebuilds per frame) ──
          AnimatedBuilder(
            animation: _anim,
            builder: (context, _) {
              final glowScale = widget.mode == 1
                  ? (0.5 + 0.5 * math.sin(_anim.value * 2 * math.pi))
                  : widget.mode == 3
                      ? 1.0
                      : (bf > 0.1 ? 1.0 : 0.0);
              final orbColor = widget.mode == 3
                  ? HSVColor.fromAHSV(
                          1.0, (_anim.value * 360) % 360, 1.0, bf)
                      .toColor()
                  : base;
              return Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: orbColor,
                  boxShadow: [
                    BoxShadow(
                        color: orbColor.withAlpha((120 * glowScale).round()),
                        blurRadius: 40,
                        spreadRadius: 8),
                    BoxShadow(
                        color: orbColor.withAlpha((60 * glowScale).round()),
                        blurRadius: 60,
                        spreadRadius: 16),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha((60 * glowScale).round()),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // ── Static parts (no per-frame rebuild) ──
          _HexLabel(color: base),
          const SizedBox(height: 16),
          _LedStrip(ctrl: _ctrl, base: base, mode: widget.mode, brightness: widget.brightness),
          const SizedBox(height: 12),
          _ModeBadges(mode: widget.mode),
        ]),
      ),
    );
  }
}

// ─── Static hex label with copy ───

class _HexLabel extends StatelessWidget {
  final Color color;
  const _HexLabel({required this.color});

  String _toHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final hex = _toHex(color);
    return Tooltip(
      message: t.copyHexTooltip(hex),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Clipboard.setData(ClipboardData(text: hex));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(t.hexCopied(hex)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(hex,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant)),
              const SizedBox(width: 4),
              Icon(Icons.copy_rounded,
                  size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── LED dot strip (animated) ───

class _LedStrip extends StatelessWidget {
  final Animation<double> ctrl;
  final Color base;
  final int mode, brightness;
  const _LedStrip(
      {required this.ctrl, required this.base, required this.mode, required this.brightness});

  Color _dotColor(int index) {
    final bf = brightness / 255.0;
    final r = (base.r * 255.0 * bf).round().clamp(0, 255);
    final g = (base.g * 255.0 * bf).round().clamp(0, 255);
    final b = (base.b * 255.0 * bf).round().clamp(0, 255);
    return switch (mode) {
      1 => () {
          final sin =
              (0.5 + 0.5 * math.sin(ctrl.value * 2 * math.pi)).clamp(0.0, 1.0);
          return Color.fromARGB(
              255, (r * sin).round(), (g * sin).round(), (b * sin).round());
        }(),
      2 => () {
          final pos = ctrl.value * 8;
          final dist = (pos - index).abs();
          final wrapped = (8 - dist).abs();
          final minDist = dist < wrapped ? dist : wrapped;
          final f = (1.0 - minDist / 2.5).clamp(0.0, 1.0);
          return Color.fromARGB(
              255, (r * f).round(), (g * f).round(), (b * f).round());
        }(),
      3 => HSVColor.fromAHSV(1.0, (ctrl.value * 360 + index * 20) % 360, 1.0, bf)
          .toColor(),
      _ => Color.fromARGB(255, r, g, b),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: cs.surfaceContainerLowest,
            border: Border.all(color: cs.outlineVariant.withAlpha(40))),
        child: Column(children: [
          Row(spacing: 8, children: List.generate(4, (i) {
            final c = _dotColor(i);
            return _LedDot(color: c);
          })),
          const SizedBox(height: 6),
          Row(spacing: 8, children: List.generate(4, (i) {
            final c = _dotColor(i + 4);
            return _LedDot(color: c);
          })),
        ]),
      ),
    );
  }
}

class _LedDot extends StatelessWidget {
  final Color color;
  const _LedDot({required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lit = color.computeLuminance() > 0.06;
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? color : cs.surfaceContainerLowest,
            boxShadow: lit
                ? [BoxShadow(color: color.withAlpha(100), blurRadius: 16, spreadRadius: 3)]
                : null,
            border: Border.all(
                color: lit
                    ? Colors.white.withAlpha(50)
                    : cs.outlineVariant.withAlpha(80),
                width: lit ? 1.5 : 1),
          ),
        ),
      ),
    );
  }
}

// ─── Mode badges (static) ───

class _ModeBadges extends StatelessWidget {
  final int mode;
  const _ModeBadges({required this.mode});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final items = [
      (t.modeStatic, cs.primary),
      (t.modeBreath, const Color(0xFF06B6D4)),
      (t.modeFlow, const Color(0xFF3B82F6)),
      (t.modeGradient, const Color(0xFF8B5CF6)),
      (t.modeMusic, const Color(0xFFEC4899)),
    ];
    return SizedBox(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: mode == i ? items[i].$2.withAlpha(25) : Colors.transparent,
                border: Border.all(
                    color: mode == i
                        ? items[i].$2.withAlpha(80)
                        : cs.outlineVariant.withAlpha(60),
                    width: mode == i ? 1.2 : 0.5),
              ),
              child: Text(items[i].$1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: mode == i
                          ? items[i].$2
                          : cs.onSurfaceVariant.withAlpha(120))),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── RGB Sliders Card ───

class _RgbSliders extends StatelessWidget {
  final int r, g, b;
  final BLEService ble;
  final WidgetRef ref;
  const _RgbSliders(
      {required this.r, required this.g, required this.b, required this.ble, required this.ref});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Icon(Icons.tune_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(t.ledStrip,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))
          ]),
          const SizedBox(height: 14),
          ChannelSlider(label: 'R', value: r, color: const Color(0xFFEF4444),
              onChanged: (v) {
            ref.read(deviceProvider.notifier).setColor(v, g, b);
            ble.setColorThrottled(v, g, b);
          }),
          const SizedBox(height: 8),
          ChannelSlider(label: 'G', value: g, color: const Color(0xFF22C55E),
              onChanged: (v) {
            ref.read(deviceProvider.notifier).setColor(r, v, b);
            ble.setColorThrottled(r, v, b);
          }),
          const SizedBox(height: 8),
          ChannelSlider(label: 'B', value: b, color: const Color(0xFF3B82F6),
              onChanged: (v) {
            ref.read(deviceProvider.notifier).setColor(r, g, v);
            ble.setColorThrottled(r, g, v);
          }),
        ]),
      ),
    );
  }
}

// ─── Preset Colors ───

int _findPresetIndex(int r, int g, int b) {
  for (int i = 0; i < presetColors.length; i++) {
    final c = Color(presetColors[i]);
    if ((c.r * 255).round() == r &&
        (c.g * 255).round() == g &&
        (c.b * 255).round() == b) {
      return i;
    }
  }
  return -1;
}

class _PresetColors extends StatelessWidget {
  final int r, g, b;
  final void Function(int r, int g, int b) onPick;
  const _PresetColors({required this.r, required this.g, required this.b, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final sel = _findPresetIndex(r, g, b);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.palette_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(t.presetColors,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))
          ]),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(presetColors.length, (i) {
              final cl = Color(presetColors[i]);
              final pr = (cl.r * 255).round();
              final pg = (cl.g * 255).round();
              final pb = (cl.b * 255).round();
              final active = i == sel;
              return GestureDetector(
                onTap: () => onPick(pr, pg, pb),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: active ? 52 : 48,
                  height: active ? 52 : 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cl,
                    boxShadow: [
                      BoxShadow(
                          color: cl.withAlpha(active ? 100 : 60),
                          blurRadius: active ? 16 : 10,
                          spreadRadius: active ? 2 : 1,
                          offset: const Offset(0, 3))
                    ],
                    border: Border.all(
                        color: active ? cs.primary : cs.outlineVariant.withAlpha(60),
                        width: active ? 2.5 : 1),
                  ),
                  child: active
                      ? Icon(Icons.check_rounded,
                          color: cl.computeLuminance() > 0.5
                              ? Colors.black54
                              : Colors.white,
                          size: 22,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 4)])
                      : null,
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

// ─── Quick Actions ───

class _QuickActions extends StatelessWidget {
  final void Function(int r, int g, int b) onColor;
  const _QuickActions({required this.onColor});
  static final _rng = math.Random();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.flash_on_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(t.quickActions,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _chip(context, Icons.power_settings_new_rounded, t.actionPowerOff, cs.error, () => onColor(0, 0, 0))),
            const SizedBox(width: 10),
            Expanded(child: _chip(context, Icons.light_mode_rounded, t.actionFullWhite, cs.tertiary, () => onColor(255, 255, 255))),
            const SizedBox(width: 10),
            Expanded(child: _chip(context, Icons.casino_rounded, t.actionRandom, cs.primary, () => onColor(_rng.nextInt(256), _rng.nextInt(256), _rng.nextInt(256)))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _chip(context, Icons.local_fire_department_rounded, t.actionWarmLight, const Color(0xFFFFB347), () => onColor(255, 179, 71))),
            const SizedBox(width: 10),
            Expanded(child: _chip(context, Icons.ac_unit_rounded, t.actionCoolLight, const Color(0xFFB3E5FC), () => onColor(179, 229, 252))),
            const SizedBox(width: 10),
            Expanded(child: _chip(context, Icons.gradient_rounded, t.actionRainbow, const Color(0xFFE879F9), () {
              final c = HSVColor.fromAHSV(1.0, _rng.nextDouble() * 360, 1.0, 1.0).toColor();
              onColor((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());
            })),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: color))),
          ]),
        ),
      ),
    );
  }
}
