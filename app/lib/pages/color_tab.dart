import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../theme/app_design.dart';
import '../utils/colors.dart';
import 'shared/ble_widgets.dart';
import 'shared/sliders.dart';

class ColorTab extends ConsumerStatefulWidget {
  const ColorTab({super.key});
  @override
  ConsumerState<ColorTab> createState() => _ColorTabState();
}

class _ColorTabState extends ConsumerState<ColorTab>
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
    if (AppMotion.reduced(context)) {
      if (_ctrl.isAnimating) _ctrl.stop();
      _ctrl.value = 0;
      return;
    }
    if (m >= 1 && m <= 3 && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if ((m == 0 || m == 4) && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) _syncAnimation();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(deviceProvider.select((s) => s.r));
    final g = ref.watch(deviceProvider.select((s) => s.g));
    final b = ref.watch(deviceProvider.select((s) => s.b));
    final brightness = ref.watch(deviceProvider.select((s) => s.brightness));
    final mode = ref.watch(deviceProvider.select((s) => s.mode));
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final color = Color.fromARGB(255, r, g, b);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad =
        MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 16;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t.appTitle),
        surfaceTintColor: Colors.transparent,
        actions: const [BleAction()],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, topPad, 16, bottomPad),
        children: [
          const BleBanner(),
          const SizedBox(height: AppSpacing.sm),
          // ── Compact LED strip + hex + mode ──
          _CompactLedStrip(
            ctrl: _ctrl,
            color: color,
            mode: mode,
            brightness: brightness,
            brightnessColor: cs.primary,
            onBrightnessChanged: (v) {
              final iv = v.round();
              ref.read(deviceProvider.notifier).setBrightness(iv);
              ble.setBrightnessThrottled(iv);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _RgbSliders(r: r, g: g, b: b, ble: ble, ref: ref),
          const SizedBox(height: AppSpacing.sm),
          _PresetColors(
            r: r,
            g: g,
            b: b,
            onPick: (r, g, b) {
              HapticFeedback.selectionClick();
              ref.read(deviceProvider.notifier).setColor(r, g, b);
              ble.setColor(r, g, b);
            },
          ),
          const SizedBox(height: 6),
          _QuickActions(
            onColor: (r, g, b) {
              HapticFeedback.lightImpact();
              ref.read(deviceProvider.notifier).setColor(r, g, b);
              ble.setColor(r, g, b);
            },
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

// ─── Compact LED strip with hex + mode inline ───

class _CompactLedStrip extends StatelessWidget {
  final AnimationController ctrl;
  final Color color;
  final Color brightnessColor;
  final int mode, brightness;
  final ValueChanged<double> onBrightnessChanged;
  const _CompactLedStrip({
    required this.ctrl,
    required this.color,
    required this.brightnessColor,
    required this.mode,
    required this.brightness,
    required this.onBrightnessChanged,
  });

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
    final brightnessPct = (brightness / 255 * 100).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Tooltip(
                  message: t.copyHexTooltip(hex),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: hex));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t.hexCopied(hex)),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hex,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: cs.onSurface,
                                ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.copy_rounded,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: _ModeBadges(mode: mode),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            RepaintBoundary(
              key: const ValueKey('led-strip-preview'),
              child: AnimatedBuilder(
                animation: ctrl,
                builder: (context, _) => SizedBox(
                  height: _LedStripPainter.previewHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LedStripPainter(
                      progress: ctrl.value,
                      color: color,
                      mode: mode,
                      brightness: brightness,
                      outline: cs.outline,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.brightness_6_rounded,
                  size: 18,
                  color: brightnessColor,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  t.brightness,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                Text(
                  t.brightnessPercent(brightnessPct),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: brightnessColor,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: brightnessColor,
                inactiveTrackColor: brightnessColor.withAlpha(28),
                thumbColor: brightnessColor,
                overlayColor: brightnessColor.withAlpha(18),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: brightness.toDouble(),
                min: 0,
                max: 255,
                onChanged: onBrightnessChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedStripPainter extends CustomPainter {
  const _LedStripPainter({
    required this.progress,
    required this.color,
    required this.mode,
    required this.brightness,
    required this.outline,
  });

  final double progress;
  final Color color;
  final int mode;
  final int brightness;
  final Color outline;

  static const double previewHeight = 132;
  static const int _columns = 4;
  static const int _rows = 2;
  static const double _preferredDotGap = 20;
  static const double _maxDotRadius = 22;
  static const double _fallbackDotRadius = 1;
  static const double _glowOutset = 3;
  static const EdgeInsets _insets = EdgeInsets.fromLTRB(12, 8, 12, 8);

  Color _dotColor(int index) {
    final bf = brightness / 255.0;
    final r = (color.r * 255.0 * bf).round().clamp(0, 255);
    final g = (color.g * 255.0 * bf).round().clamp(0, 255);
    final b = (color.b * 255.0 * bf).round().clamp(0, 255);
    return switch (mode) {
      1 => () {
        final sin = (0.5 + 0.5 * math.sin(progress * 2 * math.pi)).clamp(
          0.0,
          1.0,
        );
        return Color.fromARGB(
          255,
          (r * sin).round(),
          (g * sin).round(),
          (b * sin).round(),
        );
      }(),
      2 => () {
        final pos = progress * 8;
        final dist = (pos - index).abs();
        final wrapped = (8 - dist).abs();
        final minDist = dist < wrapped ? dist : wrapped;
        final f = (1.0 - minDist / 2.5).clamp(0.0, 1.0);
        return Color.fromARGB(
          255,
          (r * f).round(),
          (g * f).round(),
          (b * f).round(),
        );
      }(),
      3 => HSVColor.fromAHSV(
        1.0,
        (progress * 360 + index * 20) % 360,
        1.0,
        bf,
      ).toColor(),
      _ => Color.fromARGB(255, r, g, b),
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dots = computeLedStripDotLayout(size);
    if (dots.isEmpty) return;

    for (var i = 0; i < dots.length; i++) {
      final dot = dots[i];
      final c = _dotColor(i);
      final bright = c.computeLuminance() > 0.06;
      if (bright) {
        canvas.drawCircle(
          dot.center,
          dot.radius + dot.glowOutset,
          Paint()..color = c.withAlpha(34),
        );
      }
      canvas.drawCircle(dot.center, dot.radius, Paint()..color = c);
      canvas.drawCircle(
        dot.center,
        dot.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bright ? 1.4 : 1
          ..color = bright ? Colors.white.withAlpha(60) : outline.withAlpha(90),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LedStripPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.mode != mode ||
        oldDelegate.brightness != brightness ||
        oldDelegate.outline != outline;
  }
}

@visibleForTesting
class LedStripDotLayout {
  const LedStripDotLayout({
    required this.center,
    required this.radius,
    required this.glowOutset,
    required this.ledIndex,
  });

  final Offset center;
  final double radius;
  final double glowOutset;
  final int ledIndex;
}

@visibleForTesting
const List<int> ledPhysicalLayoutOrder = [3, 2, 1, 0, 4, 5, 6, 7];

@visibleForTesting
List<LedStripDotLayout> computeLedStripDotLayout(Size size) {
  const columns = _LedStripPainter._columns;
  const rows = _LedStripPainter._rows;
  const insets = _LedStripPainter._insets;
  final usableWidth = math.max(0.0, size.width - insets.horizontal);
  final usableHeight = math.max(0.0, size.height - insets.vertical);
  if (usableWidth <= 0 || usableHeight <= 0) return const [];

  final cellWidth = usableWidth / columns;
  final cellHeight = usableHeight / rows;
  final gap = math.min(
    _LedStripPainter._preferredDotGap,
    math.min(cellWidth, cellHeight) * 0.28,
  );
  final safeRadius = math.min((cellWidth - gap) / 2, (cellHeight - gap) / 2);
  final radius = math.min(
    _LedStripPainter._maxDotRadius,
    math.max(_LedStripPainter._fallbackDotRadius, safeRadius),
  );
  final glowOutset = math.min(_LedStripPainter._glowOutset, radius * 0.35);

  return List<LedStripDotLayout>.generate(ledPhysicalLayoutOrder.length, (i) {
    final row = i ~/ columns;
    final col = i % columns;
    return LedStripDotLayout(
      center: Offset(
        insets.left + cellWidth * (col + 0.5),
        insets.top + cellHeight * (row + 0.5),
      ),
      radius: radius,
      glowOutset: glowOutset,
      ledIndex: ledPhysicalLayoutOrder[i],
    );
  }, growable: false);
}

// ─── Mode badges ───

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
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.curve(context, AppMotion.standard),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: mode == i ? items[i].$2.withAlpha(20) : Colors.transparent,
              border: Border.all(
                color: mode == i
                    ? items[i].$2.withAlpha(80)
                    : Colors.transparent,
                width: mode == i ? 1 : 0,
              ),
            ),
            child: Text(
              items[i].$1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: mode == i ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
                color: mode == i
                    ? items[i].$2
                    : cs.onSurfaceVariant.withAlpha(100),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── RGB Sliders Card ───

class _RgbSliders extends StatelessWidget {
  final int r, g, b;
  final BLEService ble;
  final WidgetRef ref;
  const _RgbSliders({
    required this.r,
    required this.g,
    required this.b,
    required this.ble,
    required this.ref,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  t.ledStrip,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ChannelSlider(
              label: 'R',
              value: r,
              color: const Color(0xFFEF4444),
              onChanged: (v) {
                ref.read(deviceProvider.notifier).setColor(v, g, b);
                ble.setColorThrottled(v, g, b);
              },
            ),
            const SizedBox(height: 4),
            ChannelSlider(
              label: 'G',
              value: g,
              color: const Color(0xFF22C55E),
              onChanged: (v) {
                ref.read(deviceProvider.notifier).setColor(r, v, b);
                ble.setColorThrottled(r, v, b);
              },
            ),
            const SizedBox(height: 4),
            ChannelSlider(
              label: 'B',
              value: b,
              color: const Color(0xFF3B82F6),
              onChanged: (v) {
                ref.read(deviceProvider.notifier).setColor(r, g, v);
                ble.setColorThrottled(r, g, v);
              },
            ),
          ],
        ),
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
  const _PresetColors({
    required this.r,
    required this.g,
    required this.b,
    required this.onPick,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final sel = _findPresetIndex(r, g, b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  t.presetColors,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(presetColors.length, (i) {
                final cl = Color(presetColors[i]);
                final pr = (cl.r * 255).round();
                final pg = (cl.g * 255).round();
                final pb = (cl.b * 255).round();
                final active = i == sel;
                return GestureDetector(
                  onTap: () => onPick(pr, pg, pb),
                  child: AnimatedContainer(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    curve: AppMotion.curve(context, AppMotion.standard),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cl,
                      boxShadow: [
                        BoxShadow(
                          color: cl.withAlpha(36),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: active
                            ? cs.primary
                            : cs.outlineVariant.withAlpha(50),
                        width: active ? 2 : 0.8,
                      ),
                    ),
                    child: active
                        ? Icon(
                            Icons.check_rounded,
                            color: cl.computeLuminance() > 0.5
                                ? Colors.black54
                                : Colors.white,
                            size: 18,
                          )
                        : null,
                  ),
                );
              }),
            ),
          ],
        ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flash_on_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  t.quickActions,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _iconButton(
                    context,
                    Icons.power_settings_new_rounded,
                    t.actionPowerOff,
                    cs.error,
                    () => onColor(0, 0, 0),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _iconButton(
                    context,
                    Icons.light_mode_rounded,
                    t.actionFullWhite,
                    cs.tertiary,
                    () => onColor(255, 255, 255),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _iconButton(
                    context,
                    Icons.casino_rounded,
                    t.actionRandom,
                    cs.primary,
                    () => onColor(
                      _rng.nextInt(256),
                      _rng.nextInt(256),
                      _rng.nextInt(256),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Material(
        color: cs.surfaceContainerHighest.withAlpha(90),
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
