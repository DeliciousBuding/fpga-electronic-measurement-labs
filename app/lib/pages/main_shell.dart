import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../providers/preferences_provider.dart';
import '../utils/colors.dart';
import 'scanner_page.dart';
import 'settings_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> with SingleTickerProviderStateMixin {
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
      } else if (event is BleConnectionEvent && event.connected && event.name != null) {
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
    final hideBar = ref.watch(preferencesProvider.select((p) => p.hideBarOnScroll));
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
        children: const [_ColorTab(), _EffectTab(), _SceneTab(), SettingsPage()],
      ),
      bottomNavigationBar: ClipRect(
        child: Align(alignment: Alignment.topCenter, heightFactor: visibility,
          child: Opacity(opacity: visibility,
            child: NavigationBar(
              selectedIndex: _index, animationDuration: const Duration(milliseconds: 400),
              onDestinationSelected: (i) { ref.read(barVisibilityProvider.notifier).show(); _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic); setState(() => _index = i); },
              destinations: [
                NavigationDestination(icon: const Icon(Icons.lightbulb_outline_rounded, size: 22), selectedIcon: const Icon(Icons.lightbulb_rounded, size: 22), label: t.navLed),
                NavigationDestination(icon: const Icon(Icons.auto_awesome_rounded, size: 22), selectedIcon: const Icon(Icons.auto_awesome_rounded, size: 22), label: t.navEffect),
                NavigationDestination(icon: const Icon(Icons.bookmark_border_rounded, size: 22), selectedIcon: const Icon(Icons.bookmark_rounded, size: 22), label: t.navScene),
                NavigationDestination(icon: const Icon(Icons.tune_rounded, size: 22), selectedIcon: const Icon(Icons.tune_rounded, size: 22), label: t.navSettings),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BleBanner extends ConsumerWidget {
  const _BleBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (context, connected, _) => AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
        child: connected ? const SizedBox.shrink() : Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: cs.errorContainer,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
            Icon(Icons.bluetooth_disabled_rounded, size: 20, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text(t.bleNotConnected, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onErrorContainer))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact), child: Text(t.bleConnect, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: cs.onErrorContainer))),
          ])),
        ),
      ),
    );
  }
}

class _BleAction extends ConsumerWidget {
  const _BleAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (context, connected, _) => Tooltip(
        message: connected ? t.bleTooltipConnected(ble.deviceName) : t.bleTooltipDisconnected,
        child: IconButton(
          icon: connected
              ? Badge(isLabelVisible: true, smallSize: 8, child: Icon(Icons.bluetooth_connected_rounded, color: cs.primary))
              : Icon(Icons.bluetooth_rounded, color: cs.onSurfaceVariant.withAlpha(150)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())),
          onLongPress: connected
              ? () {
                  ble.queryStatus();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t.bleRefreshing),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ));
                }
              : null,
        ),
      ),
    );
  }
}

int _findPresetIndex(int r, int g, int b) {
  for (int i = 0; i < presetColors.length; i++) {
    final c = Color(presetColors[i]);
    if ((c.r * 255).round() == r && (c.g * 255).round() == g && (c.b * 255).round() == b) return i;
  }
  return -1;
}

// ─── Color Tab ───

class _ColorTab extends ConsumerWidget {
  const _ColorTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final color = Color.fromARGB(255, s.r, s.g, s.b);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.appTitle), centerTitle: false, elevation: 0, scrolledUnderElevation: 1, surfaceTintColor: Colors.transparent, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, bottomPad), children: [
        const SizedBox(height: 4),
        const _BleBanner(),
        const SizedBox(height: 16),
        _ColorHero(color: color, mode: s.mode, brightness: s.brightness),
        const SizedBox(height: 20),
        _SliderCard(label: t.brightness, icon: Icons.brightness_6_rounded, value: s.brightness.toDouble(), min: 0, max: 255, color: cs.primary,
            onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBrightness(iv); ble.setBrightnessThrottled(iv); }),
        const SizedBox(height: 12),
        _ColorSlidersCard(r: s.r, g: s.g, b: s.b,
            onR: (v) { ref.read(deviceProvider.notifier).setColor(v, s.g, s.b); ble.setColorThrottled(v, s.g, s.b); },
            onG: (v) { ref.read(deviceProvider.notifier).setColor(s.r, v, s.b); ble.setColorThrottled(s.r, v, s.b); },
            onB: (v) { ref.read(deviceProvider.notifier).setColor(s.r, s.g, v); ble.setColorThrottled(s.r, s.g, v); }),
        const SizedBox(height: 12),
        _PresetColors(r: s.r, g: s.g, b: s.b, onPick: (r, g, b) { HapticFeedback.selectionClick(); ref.read(deviceProvider.notifier).setColor(r, g, b); ble.setColor(r, g, b); }),
        const SizedBox(height: 12),
        _QuickActions(onColor: (r, g, b) { HapticFeedback.lightImpact(); ref.read(deviceProvider.notifier).setColor(r, g, b); ble.setColor(r, g, b); }),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _ColorHero extends StatefulWidget {
  final Color color; final int mode; final int brightness;
  const _ColorHero({required this.color, required this.mode, required this.brightness});
  @override
  State<_ColorHero> createState() => _ColorHeroState();
}

class _ColorHeroState extends State<_ColorHero> with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _anim = CurvedAnimation(parent: _ticker, curve: Curves.easeInOut);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(covariant _ColorHero old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) _updateAnimation();
  }

  void _updateAnimation() {
    if (widget.mode >= 1 && widget.mode <= 3) {
      if (!_ticker.isAnimating) _ticker.repeat();
    } else {
      _ticker.stop();
    }
  }

  @override
  void dispose() { _ticker.dispose(); super.dispose(); }

  Color _ledColor(int index, Color base) {
    final bf = widget.brightness / 255.0;
    final r = (base.r * 255.0 * bf).round().clamp(0, 255);
    final g = (base.g * 255.0 * bf).round().clamp(0, 255);
    final b = (base.b * 255.0 * bf).round().clamp(0, 255);
    switch (widget.mode) {
      case 1:
        final v = _anim.value * 2 * math.pi;
        final sin = (0.5 + 0.5 * math.sin(v)).clamp(0.0, 1.0);
        return Color.fromARGB(255, (r * sin).round(), (g * sin).round(), (b * sin).round());
      case 2:
        final t = _anim.value * 8;
        final pos = t % 8;
        final dist = (pos - index).abs();
        final wrapped = (8 - dist).abs();
        final minDist = dist < wrapped ? dist : wrapped;
        final f = (1.0 - minDist / 2.5).clamp(0.0, 1.0);
        return Color.fromARGB(255, (r * f).round(), (g * f).round(), (b * f).round());
      case 3:
        final hue = (_anim.value * 360 + index * 20) % 360;
        return HSVColor.fromAHSV(1.0, hue, 1.0, bf).toColor();
      default:
        return Color.fromARGB(255, r, g, b);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final base = widget.color;
    final bf = widget.brightness / 255.0;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        // orb glow intensity for breath/gradient
        final glowScale = widget.mode == 1
            ? (0.5 + 0.5 * math.sin(_anim.value * 2 * math.pi))
            : widget.mode == 3 ? 1.0 : (bf > 0.1 ? 1.0 : 0.0);
        final orbColor = widget.mode == 3
            ? HSVColor.fromAHSV(1.0, (_anim.value * 360) % 360, 1.0, bf).toColor()
            : base;

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16), child: Column(children: [
            // large color orb
            Center(child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: orbColor,
                boxShadow: [
                  BoxShadow(color: orbColor.withAlpha((120 * glowScale).round()), blurRadius: 40, spreadRadius: 8),
                  BoxShadow(color: orbColor.withAlpha((60 * glowScale).round()), blurRadius: 60, spreadRadius: 16),
                ],
              ),
              child: Center(child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha((60 * glowScale).round()),
                ),
              )),
            )),
            const SizedBox(height: 12),
            // hex label
            Builder(builder: (context) {
              final hex = '#${(widget.color.r * 255).round().toRadixString(16).padLeft(2, '0')}${(widget.color.g * 255).round().toRadixString(16).padLeft(2, '0')}${(widget.color.b * 255).round().toRadixString(16).padLeft(2, '0')}'.toUpperCase();
              return Tooltip(
                message: t.copyHexTooltip(hex),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () { Clipboard.setData(ClipboardData(text: hex)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.hexCopied(hex)), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1))); },
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(hex, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, fontFamily: 'monospace', color: cs.onSurfaceVariant)),
                    const SizedBox(width: 4),
                    Icon(Icons.copy_rounded, size: 14, color: cs.onSurfaceVariant.withAlpha(120)),
                  ])),
                ),
              );
            }),
            const SizedBox(height: 12),
            // LED dots strip
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.surfaceContainerLowest, border: Border.all(color: cs.outlineVariant.withAlpha(40))), child: Column(children: [
              Row(spacing: 8, children: List.generate(4, (i) => _LedDot(color: _ledColor(i, base)))),
              const SizedBox(height: 6),
              Row(spacing: 8, children: List.generate(4, (i) => _LedDot(color: _ledColor(i + 4, base)))),
            ])),
            const SizedBox(height: 12),
            // mode badges
            SizedBox(height: 30, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _ModeBadge(active: widget.mode == 0, label: t.modeStatic, color: cs.primary),
              const SizedBox(width: 6),
              _ModeBadge(active: widget.mode == 1, label: t.modeBreath, color: const Color(0xFF06B6D4)),
              const SizedBox(width: 6),
              _ModeBadge(active: widget.mode == 2, label: t.modeFlow, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 6),
              _ModeBadge(active: widget.mode == 3, label: t.modeGradient, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 6),
              _ModeBadge(active: widget.mode == 4, label: t.modeMusic, color: const Color(0xFFEC4899)),
            ])),
          ])),
        );
      },
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
      child: AspectRatio(aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? color : cs.surfaceContainerLowest,
            boxShadow: lit ? [BoxShadow(color: color.withAlpha(100), blurRadius: 16, spreadRadius: 3)] : null,
            border: Border.all(color: lit ? Colors.white.withAlpha(50) : cs.outlineVariant.withAlpha(80), width: lit ? 1.5 : 1),
          ),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final bool active; final String label; final Color color;
  const _ModeBadge({required this.active, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: active ? color.withAlpha(25) : Colors.transparent, border: Border.all(color: active ? color.withAlpha(80) : Theme.of(context).colorScheme.outlineVariant.withAlpha(60), width: active ? 1.2 : 0.5)),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: active ? color : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(120))),
    );
  }
}

// ─── Shared Widgets ───

class _SliderCard extends StatelessWidget {
  final String label; final IconData icon; final double value, min, max; final Color color; final ValueChanged<double> onChanged;
  const _SliderCard({required this.label, required this.icon, required this.value, required this.min, required this.max, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final pct = ((value - min) / (max - min) * 100).round();
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 8), Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withAlpha(25)), child: Text(t.brightnessPercent(pct), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: color)))]),
        SliderTheme(data: SliderThemeData(trackHeight: 6, thumbShape: _GlowThumb(color: color), activeTrackColor: color, inactiveTrackColor: color.withAlpha(30), thumbColor: color, overlayColor: color.withAlpha(20), overlayShape: const RoundSliderOverlayShape(overlayRadius: 18)), child: Slider(value: value, min: min, max: max, onChanged: onChanged)),
      ])),
    );
  }
}

class _GlowThumb extends RoundSliderThumbShape {
  final Color color;
  const _GlowThumb({required this.color}) : super(enabledThumbRadius: 10);
  @override
  void paint(PaintingContext context, Offset center, {required Animation<double> activationAnimation, required Animation<double> enableAnimation, required bool isDiscrete, required TextPainter labelPainter, required RenderBox parentBox, required SliderThemeData sliderTheme, required TextDirection textDirection, required double value, required double textScaleFactor, required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    final r = 10.0 * enableAnimation.value;
    canvas.drawCircle(center, r + 4, Paint()..color = color.withAlpha(40)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(center, r, Paint()..color = color..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.drawCircle(center, r, Paint()..color = Colors.white.withAlpha(200));
    canvas.drawCircle(center, r * 0.75, Paint()..color = color);
  }
}

class _ColorSlidersCard extends StatelessWidget {
  final int r, g, b; final ValueChanged<int> onR, onG, onB;
  const _ColorSlidersCard({required this.r, required this.g, required this.b, required this.onR, required this.onG, required this.onB});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [Icon(Icons.tune_rounded, size: 18, color: cs.primary), const SizedBox(width: 8), Text(t.ledStrip, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))]),
        const SizedBox(height: 14),
        _SliverRow(label: 'R', icon: Icons.circle, value: r, color: const Color(0xFFEF4444), onChanged: onR),
        const SizedBox(height: 8), _SliverRow(label: 'G', icon: Icons.circle, value: g, color: const Color(0xFF22C55E), onChanged: onG),
      const SizedBox(height: 8), _SliverRow(label: 'B', icon: Icons.circle, value: b, color: const Color(0xFF3B82F6), onChanged: onB),
    ])),
  );
}
}

class _SliverRow extends StatelessWidget {
  final String label; final IconData icon; final int value; final Color color; final ValueChanged<int> onChanged;
  const _SliverRow({required this.label, required this.icon, required this.value, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(width: 36, child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color))])),
      Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 5, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7), activeTrackColor: color, inactiveTrackColor: color.withAlpha(25), thumbColor: color, overlayColor: color.withAlpha(20), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)), child: Slider(value: value.toDouble(), min: 0, max: 255, onChanged: (x) => onChanged(x.round())))),
      SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.end, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurfaceVariant))),
    ]);
  }
}

class _PresetColors extends StatelessWidget {
  final int r, g, b; final void Function(int r, int g, int b) onPick;
  const _PresetColors({required this.r, required this.g, required this.b, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sel = _findPresetIndex(r, g, b);
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.palette_rounded, size: 18, color: cs.primary), const SizedBox(width: 8), Text(AppLocalizations.of(context)!.presetColors, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))]),
        const SizedBox(height: 16),
        Wrap(spacing: 14, runSpacing: 14, children: List.generate(presetColors.length, (i) {
          final cl = Color(presetColors[i]);
          final pr = (cl.r * 255).round(); final pg = (cl.g * 255).round(); final pb = (cl.b * 255).round();
          final active = i == sel;
          return GestureDetector(onTap: () => onPick(pr, pg, pb),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: active ? 52 : 48, height: active ? 52 : 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: cl,
                boxShadow: [BoxShadow(color: cl.withAlpha(active ? 100 : 60), blurRadius: active ? 16 : 10, spreadRadius: active ? 2 : 1, offset: const Offset(0, 3))],
                border: Border.all(color: active ? cs.primary : cs.outlineVariant.withAlpha(60), width: active ? 2.5 : 1),
              ),
              child: active ? Icon(Icons.check_rounded, color: cl.computeLuminance() > 0.5 ? Colors.black54 : Colors.white, size: 22, shadows: const [Shadow(color: Colors.black26, blurRadius: 4)]) : null,
            ),
          );
        })),
      ])),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final void Function(int r, int g, int b) onColor;
  const _QuickActions({required this.onColor});

  static final _rng = math.Random();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.flash_on_rounded, size: 18, color: cs.primary), const SizedBox(width: 8), Text(t.quickActions, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface))]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _actionChip(context, Icons.power_settings_new_rounded, t.actionPowerOff, cs.error, () => onColor(0, 0, 0))),
          const SizedBox(width: 10),
          Expanded(child: _actionChip(context, Icons.light_mode_rounded, t.actionFullWhite, cs.tertiary, () => onColor(255, 255, 255))),
          const SizedBox(width: 10),
          Expanded(child: _actionChip(context, Icons.casino_rounded, t.actionRandom, cs.primary, () => onColor(_rng.nextInt(256), _rng.nextInt(256), _rng.nextInt(256)))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _actionChip(context, Icons.local_fire_department_rounded, t.actionWarmLight, const Color(0xFFFFB347), () => onColor(255, 179, 71))),
          const SizedBox(width: 10),
          Expanded(child: _actionChip(context, Icons.ac_unit_rounded, t.actionCoolLight, const Color(0xFFB3E5FC), () => onColor(179, 229, 252))),
          const SizedBox(width: 10),
          Expanded(child: _actionChip(context, Icons.gradient_rounded, t.actionRainbow, const Color(0xFFE879F9), () {
            final hue = (_rng.nextDouble() * 360);
            final c = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
            onColor((c.r * 255).round(), (c.g * 255).round(), (c.b * 255).round());
          })),
        ]),
      ])),
    );
  }

  Widget _actionChip(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withAlpha(15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: color))),
        ])),
      ),
    );
  }
}

// ─── Effect Tab ───

class _EffectTab extends ConsumerWidget {
  const _EffectTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    final items = [
      (0, t.modeStatic, Icons.light_mode_rounded, t.descStatic, Color(0xFFFFD93D), false),
      (1, t.modeBreath, Icons.air_rounded, t.descBreath, Color(0xFF06B6D4), false),
      (2, t.modeFlow, Icons.waves_rounded, t.descFlow, Color(0xFF3B82F6), false),
      (3, t.modeGradient, Icons.gradient_rounded, t.descGradient, Color(0xFF8B5CF6), false),
      (4, t.modeMusic, Icons.music_note_rounded, t.descMusic, Color(0xFFEC4899), true),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.navEffect), centerTitle: false, elevation: 0, scrolledUnderElevation: 1, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, bottomPad), children: [
        const SizedBox(height: 4), const _BleBanner(), const SizedBox(height: 12),
        ...items.map((m) {
          final sel = s.mode == m.$1;
          final disabled = m.$6;
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: sel ? BorderSide(color: m.$5.withAlpha(120), width: 1.5) : BorderSide(color: cs.outlineVariant.withAlpha(60))),
              color: disabled ? cs.surfaceContainerLowest : (sel ? cs.primaryContainer : cs.surfaceContainerLow),
              child: InkWell(borderRadius: BorderRadius.circular(12),
                onTap: disabled ? null : () { HapticFeedback.selectionClick(); ref.read(deviceProvider.notifier).setMode(m.$1); ble.setMode(m.$1); },
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  _EffectPreview(mode: m.$1, color: m.$5, active: sel, disabled: disabled),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.$2, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: disabled ? cs.onSurfaceVariant.withAlpha(80) : (sel ? cs.onPrimaryContainer : cs.onSurface))),
                    const SizedBox(height: 2),
                    Text(m.$4, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: disabled ? cs.onSurfaceVariant.withAlpha(60) : (sel ? cs.onPrimaryContainer.withAlpha(180) : cs.onSurfaceVariant))),
                  ])),
                  if (disabled) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: cs.outlineVariant.withAlpha(30)), child: Text(t.wip, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant.withAlpha(100))))
                  else if (sel) Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: m.$5), child: const Icon(Icons.check_rounded, color: Colors.white, size: 18)),
                ])),
              ),
            ),
          );
        }),
        if (s.mode == 2 || s.mode == 3) ...[ const SizedBox(height: 4), _SliderCard(label: s.mode == 2 ? t.flowSpeed : t.gradientSpeed, icon: Icons.speed_rounded, value: s.flowSpeed.toDouble(), min: 1, max: 255, color: s.mode == 2 ? const Color(0xFF3B82F6) : const Color(0xFF8B5CF6), onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setFlowSpeed(iv); ble.setFlowSpeedThrottled(iv); }) ],
        if (s.mode == 1) ...[ const SizedBox(height: 4), _SliderCard(label: t.breathPeriod, icon: Icons.timelapse_rounded, value: s.breathPeriod.toDouble(), min: 1, max: 255, color: const Color(0xFF06B6D4), onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBreathPeriod(iv); ble.setBreathPeriodThrottled(iv); }) ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _EffectPreview extends StatefulWidget {
  final int mode; final Color color; final bool active, disabled;
  const _EffectPreview({required this.mode, required this.color, required this.active, required this.disabled});
  @override
  State<_EffectPreview> createState() => _EffectPreviewState();
}

class _EffectPreviewState extends State<_EffectPreview> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.active) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _EffectPreview old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.active && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.disabled ? cs.onSurfaceVariant.withAlpha(60) : widget.color;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: widget.active ? c.withAlpha(30) : cs.surfaceContainerLowest),
        child: Center(child: Row(mainAxisSize: MainAxisSize.min, spacing: 3, children: List.generate(4, (i) {
          final alpha = switch (widget.mode) {
            0 => 1.0,
            1 => 0.5 + 0.5 * math.sin(_ctrl.value * 2 * math.pi),
            2 => () { final pos = _ctrl.value * 4; final d = (pos - i).abs(); return (1.0 - d).clamp(0.2, 1.0); }(),
            _ => 1.0,
          };
          final dotColor = widget.mode == 3
              ? HSVColor.fromAHSV(1.0, (_ctrl.value * 360 + i * 30) % 360, 1.0, 1.0).toColor()
              : c;
          final f = widget.mode == 3 ? 1.0 : alpha.clamp(0.1, 1.0);
          return Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromARGB((f * 255).round(), (dotColor.r * 255).round(), (dotColor.g * 255).round(), (dotColor.b * 255).round()),
              boxShadow: f > 0.5 ? [BoxShadow(color: dotColor.withAlpha((f * 60).round()), blurRadius: 4)] : null,
            ),
          );
        }))),
      ),
    );
  }
}

// ─── Scene Tab ───

class _SceneTab extends ConsumerWidget {
  const _SceneTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final s = ref.watch(deviceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    final scenes = [
      (Icons.wb_twilight_rounded, Color(0xFFEF4444), t.sceneSunset, [Color(0xFFFF6B35), Color(0xFFFFD700)]),
      (Icons.auto_awesome_rounded, Color(0xFF06B6D4), t.sceneAurora, [Color(0xFF00FF87), Color(0xFF60EFFF)]),
      (Icons.nightlife_rounded, Color(0xFF8B5CF6), t.sceneNeon, [Color(0xFFFF00FF), Color(0xFF00FFFF)]),
      (Icons.local_fire_department_rounded, Color(0xFFF97316), t.sceneFlame, [Color(0xFFFF0000), Color(0xFFFF8C00)]),
      (Icons.forest_rounded, Color(0xFF22C55E), t.sceneForest, [Color(0xFF228B22), Color(0xFF7CFC00)]),
      (Icons.water_drop_rounded, Color(0xFF38BDF8), t.sceneOcean, [Color(0xFF001F5C), Color(0xFF00B4D8)]),
      (Icons.wb_sunny_rounded, Color(0xFFFBBF24), t.sceneWarmSun, [Color(0xFFFFE4B5), Color(0xFFFFD700)]),
      (Icons.bolt_rounded, Color(0xFFE879F9), t.sceneLightning, [Color(0xFFE040FB), Color(0xFF00E5FF)]),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.sceneTitle), centerTitle: false, elevation: 0, scrolledUnderElevation: 1, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, bottomPad), children: [
        const SizedBox(height: 4), const _BleBanner(), const SizedBox(height: 12),
        Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant), const SizedBox(width: 6), Text(t.sceneHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))]),
        const SizedBox(height: 16),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15),
          itemCount: 8,
          itemBuilder: (_, i) {
            final scene = scenes[i];
            final accent = scene.$2;
            final colors = scene.$4;
            final saved = s.sceneSaved.length > i && s.sceneSaved[i];
            return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: saved ? BorderSide(color: accent.withAlpha(120), width: 1.5) : BorderSide(color: cs.outlineVariant.withAlpha(60))),
              color: saved ? accent.withAlpha(15) : cs.surfaceContainerLow,
              child: InkWell(borderRadius: BorderRadius.circular(12),
                onTap: () { HapticFeedback.selectionClick(); ble.loadScene(i); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sceneLoaded(scene.$3)), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating)); Future.delayed(const Duration(milliseconds: 300), () => ble.queryStatus()); },
                onLongPress: () { HapticFeedback.mediumImpact(); ble.saveScene(i); ref.read(deviceProvider.notifier).markSceneSaved(i); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.sceneSaved(scene.$3)), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating)); },
                child: Padding(padding: const EdgeInsets.all(12), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight)), child: Icon(scene.$1, color: Colors.white.withAlpha(220), size: 24)),
                    if (saved) Positioned(right: -3, top: -3, child: Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: accent, border: Border.all(color: Colors.white, width: 1.5)), child: const Icon(Icons.check_rounded, color: Colors.white, size: 11))),
                  ]),
                  const SizedBox(height: 8),
                  Text(scene.$3, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                ])),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
