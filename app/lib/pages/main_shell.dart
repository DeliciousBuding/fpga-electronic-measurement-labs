import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final hideBar = ref.watch(preferencesProvider.select((p) => p.hideBarOnScroll));
    final barVis = ref.watch(barVisibilityProvider);
    final visibility = hideBar ? barVis : 1.0;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: _buildTab(_index),
      ),
      bottomNavigationBar: ClipRect(
        child: Align(alignment: Alignment.topCenter, heightFactor: visibility,
          child: Opacity(opacity: visibility,
            child: NavigationBar(
              selectedIndex: _index, animationDuration: const Duration(milliseconds: 400),
              onDestinationSelected: (i) { ref.read(barVisibilityProvider.notifier).show(); setState(() => _index = i); },
              indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.palette_outlined, size: 22), selectedIcon: Icon(Icons.palette_rounded, size: 22), label: '颜色'),
                NavigationDestination(icon: Icon(Icons.auto_awesome_outlined, size: 22), selectedIcon: Icon(Icons.auto_awesome_rounded, size: 22), label: '灯效'),
                NavigationDestination(icon: Icon(Icons.bookmark_outlined, size: 22), selectedIcon: Icon(Icons.bookmark_rounded, size: 22), label: '情景'),
                NavigationDestination(icon: Icon(Icons.settings_outlined, size: 22), selectedIcon: Icon(Icons.settings_rounded, size: 22), label: '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int i) => KeyedSubtree(key: ValueKey(i), child: switch (i) {
    0 => const _ColorTab(), 1 => const _EffectTab(), 2 => const _SceneTab(), _ => const SettingsPage(),
  });
}

class _BleBanner extends ConsumerWidget {
  const _BleBanner();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (_, connected, __) => AnimatedSize(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut,
        child: connected ? const SizedBox.shrink() : Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: cs.errorContainer,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), child: Row(children: [
            Icon(Icons.bluetooth_disabled_rounded, size: 20, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text('未连接蓝牙设备', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onErrorContainer))),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact), child: Text('连接', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onErrorContainer))),
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
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (_, connected, __) => IconButton(
        icon: connected
            ? Badge(isLabelVisible: true, smallSize: 8, child: Icon(Icons.bluetooth_connected_rounded, color: cs.primary))
            : Icon(Icons.bluetooth_rounded, color: cs.onSurfaceVariant.withAlpha(150)),
        tooltip: connected ? '已连接 ${ble.deviceName}' : '未连接 - 点击扫描',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())),
      ),
    );
  }
}

int _findPresetIndex(int r, int g, int b) {
  for (int i = 0; i < presetColors.length; i++) {
    final c = Color(presetColors[i].$1);
    if ((c.r * 255).round() == r && (c.g * 255).round() == g && (c.b * 255).round() == b) return i;
  }
  return -1;
}

class _ColorTab extends ConsumerWidget {
  const _ColorTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final color = Color.fromARGB(255, s.r, s.g, s.b);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('RGB Controller'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, 20), children: [
        const SizedBox(height: 4),
        const _BleBanner(),
        const SizedBox(height: 12),
        _LedStrip(color: color, mode: s.mode, brightness: s.brightness, cs: cs),
        const SizedBox(height: 16),
        _RgbDisplay(r: s.r, g: s.g, b: s.b, cs: cs),
        const SizedBox(height: 16),
        _SliderCard(label: '亮度', icon: Icons.brightness_7_rounded, value: s.brightness.toDouble(), min: 1, max: 255, color: cs.primary,
            onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBrightness(iv); ble.setBrightness(iv); }),
        const SizedBox(height: 12),
        _ColorSlidersCard(r: s.r, g: s.g, b: s.b, cs: cs,
            onR: (v) { ref.read(deviceProvider.notifier).setColor(v, s.g, s.b); ble.setColor(v, s.g, s.b); },
            onG: (v) { ref.read(deviceProvider.notifier).setColor(s.r, v, s.b); ble.setColor(s.r, v, s.b); },
            onB: (v) { ref.read(deviceProvider.notifier).setColor(s.r, s.g, v); ble.setColor(s.r, s.g, v); }),
        const SizedBox(height: 12),
        _PresetColors(cs: cs, r: s.r, g: s.g, b: s.b, onPick: (r, g, b) { ref.read(deviceProvider.notifier).setColor(r, g, b); ble.setColor(r, g, b); }),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _LedStrip extends StatelessWidget {
  final Color color; final int mode; final int brightness; final ColorScheme cs;
  const _LedStrip({required this.color, required this.mode, required this.brightness, required this.cs});

  @override
  Widget build(BuildContext context) {
    final bf = brightness / 255.0;
    final litColor = Color.fromARGB(255, (color.r * bf).round().clamp(0, 255), (color.g * bf).round().clamp(0, 255), (color.b * bf).round().clamp(0, 255));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.fromLTRB(16, 20, 16, 16), child: Column(children: [
        Row(children: [Icon(Icons.light_rounded, size: 18, color: cs.primary), const SizedBox(width: 8), Text('LED 灯带', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)), const Spacer(), Badge(backgroundColor: color, label: Text('$brightness', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white))), const SizedBox(width: 8), Text('亮度', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: cs.surfaceContainerLowest),
          child: Column(children: [
            Row(spacing: 10, children: List.generate(4, (i) => _LedDot(color: litColor, cs: cs))),
            const SizedBox(height: 8),
            Row(spacing: 10, children: List.generate(4, (i) => _LedDot(color: litColor, cs: cs))),
          ]),
        ),
        const SizedBox(height: 12),
        SizedBox(height: 32, child: Row(children: [
          _ModeBadge(active: mode == 0, label: '静态', color: cs.primary),
          const SizedBox(width: 6),
          _ModeBadge(active: mode == 1, label: '呼吸', color: const Color(0xFF06B6D4)),
          const SizedBox(width: 6),
          _ModeBadge(active: mode == 2, label: '流水', color: const Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          _ModeBadge(active: mode == 3, label: '渐变', color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
          _ModeBadge(active: mode == 4, label: '音乐', color: const Color(0xFFEC4899)),
        ])),
      ])),
    );
  }
}

class _LedDot extends StatelessWidget {
  final Color color; final ColorScheme cs;
  const _LedDot({required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    final lit = color.computeLuminance() > 0.06;
    return Expanded(
      child: AspectRatio(aspectRatio: 1,
        child: AnimatedContainer(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lit ? color : cs.surfaceContainerHighest,
            boxShadow: lit ? [BoxShadow(color: color.withAlpha(80), blurRadius: 12, spreadRadius: 2)] : null,
            border: Border.all(color: lit ? Colors.white.withAlpha(40) : cs.outlineVariant.withAlpha(80), width: lit ? 1.5 : 1),
          ),
          child: lit ? Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(50)))) : null,
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
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: active ? color.withAlpha(25) : Colors.transparent, border: Border.all(color: active ? color.withAlpha(80) : cs.outlineVariant.withAlpha(60), width: active ? 1.2 : 0.5)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? color : cs.onSurfaceVariant.withAlpha(120))),
    );
  }
}

class _RgbDisplay extends StatelessWidget {
  final int r, g, b; final ColorScheme cs;
  const _RgbDisplay({required this.r, required this.g, required this.b, required this.cs});
  @override
  Widget build(BuildContext context) => Center(
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40), color: cs.surfaceContainerLowest, boxShadow: [BoxShadow(color: cs.shadow.withAlpha(20), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _Chip(label: 'R', value: r, color: const Color(0xFFEF4444)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurfaceVariant.withAlpha(80)))),
        _Chip(label: 'G', value: g, color: const Color(0xFF22C55E)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.onSurfaceVariant.withAlpha(80)))),
        _Chip(label: 'B', value: b, color: const Color(0xFF3B82F6)),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label; final int value; final Color color;
  const _Chip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
    const SizedBox(width: 4),
    Text('$value', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
  ]);
}

class _SliderCard extends StatelessWidget {
  final String label; final IconData icon; final double value, min, max; final Color color; final ValueChanged<double> onChanged;
  const _SliderCard({required this.label, required this.icon, required this.value, required this.min, required this.max, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = ((value - min) / (max - min) * 100).round();
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20, color: color), const SizedBox(width: 8), Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withAlpha(25)), child: Text('$pct%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)))]),
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
  final int r, g, b; final ColorScheme cs; final ValueChanged<int> onR, onG, onB;
  const _ColorSlidersCard({required this.r, required this.g, required this.b, required this.cs, required this.onR, required this.onG, required this.onB});
  @override
  Widget build(BuildContext context) => Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 12, 12), child: Column(children: [
      _SliverRow(label: 'R', icon: Icons.circle, value: r, color: const Color(0xFFEF4444), onChanged: onR),
      const SizedBox(height: 8), _SliverRow(label: 'G', icon: Icons.circle, value: g, color: const Color(0xFF22C55E), onChanged: onG),
      const SizedBox(height: 8), _SliverRow(label: 'B', icon: Icons.circle, value: b, color: const Color(0xFF3B82F6), onChanged: onB),
    ])),
  );
}

class _SliverRow extends StatelessWidget {
  final String label; final IconData icon; final int value; final Color color; final ValueChanged<int> onChanged;
  const _SliverRow({required this.label, required this.icon, required this.value, required this.color, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      SizedBox(width: 36, child: Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color))])),
      Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 5, thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7), activeTrackColor: color, inactiveTrackColor: color.withAlpha(25), thumbColor: color, overlayColor: color.withAlpha(20), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)), child: Slider(value: value.toDouble(), min: 0, max: 255, onChanged: (x) => onChanged(x.round())))),
      SizedBox(width: 36, child: Text('$value', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant))),
    ]);
  }
}

class _PresetColors extends StatelessWidget {
  final ColorScheme cs; final int r, g, b; final void Function(int r, int g, int b) onPick;
  const _PresetColors({required this.cs, required this.r, required this.g, required this.b, required this.onPick});
  @override
  Widget build(BuildContext context) {
    final sel = _findPresetIndex(r, g, b);
    return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.palette_rounded, size: 18, color: cs.primary), const SizedBox(width: 8), Text('预设颜色', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface))]),
        const SizedBox(height: 16),
        Wrap(spacing: 14, runSpacing: 14, children: List.generate(presetColors.length, (i) {
          final e = presetColors[i]; final cl = Color(e.$1);
          final pr = (cl.r * 255).round(); final pg = (cl.g * 255).round(); final pb = (cl.b * 255).round();
          final active = i == sel;
          return GestureDetector(onTap: () => onPick(pr, pg, pb),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              width: active ? 52 : 48, height: active ? 52 : 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: cl,
                boxShadow: [BoxShadow(color: cl.withAlpha(active ? 100 : 60), blurRadius: active ? 16 : 10, spreadRadius: active ? 2 : 1, offset: const Offset(0, 3))],
                border: Border.all(color: active ? cs.primary : cs.outlineVariant.withAlpha(60), width: active ? 2.5 : 1),
              ),
              child: active ? const Icon(Icons.check_rounded, color: Colors.white, size: 22, shadows: [Shadow(color: Colors.black26, blurRadius: 4)]) : null,
            ),
          );
        })),
      ])),
    );
  }
}

class _EffectTab extends ConsumerWidget {
  const _EffectTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    final items = [
      (0, '静态', Icons.light_mode_rounded, '固定颜色常亮', Color(0xFFFFD93D)),
      (1, '呼吸', Icons.air_rounded, '正弦包络周期明暗', Color(0xFF06B6D4)),
      (2, '流水', Icons.waves_rounded, '灯光逐位移动', Color(0xFF3B82F6)),
      (3, '渐变', Icons.gradient_rounded, 'HSV 色相平滑过渡', Color(0xFF8B5CF6)),
      (4, '音乐', Icons.music_note_rounded, '随音频节拍律动', Color(0xFFEC4899)),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('灯效'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, 20), children: [
        const SizedBox(height: 4), const _BleBanner(), const SizedBox(height: 12),
        ...items.map((m) {
          final sel = s.mode == m.$1;
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: sel ? BorderSide(color: m.$5.withAlpha(120), width: 1.5) : BorderSide(color: cs.outlineVariant.withAlpha(60))),
              color: sel ? cs.primaryContainer : cs.surfaceContainerLow,
              child: InkWell(borderRadius: BorderRadius.circular(12),
                onTap: () { ref.read(deviceProvider.notifier).setMode(m.$1); ble.setMode(m.$1); },
                child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                  AnimatedContainer(duration: const Duration(milliseconds: 300), width: 52, height: 52, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: sel ? m.$5.withAlpha(30) : cs.surfaceContainerLowest), child: Icon(m.$3, color: sel ? m.$5 : cs.onSurfaceVariant, size: 28)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.$2, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: sel ? cs.onPrimaryContainer : cs.onSurface)),
                    const SizedBox(height: 2),
                    Text(m.$4, style: TextStyle(fontSize: 13, color: sel ? cs.onPrimaryContainer.withAlpha(180) : cs.onSurfaceVariant)),
                  ])),
                  if (sel) Container(width: 28, height: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: m.$5), child: const Icon(Icons.check_rounded, color: Colors.white, size: 18)),
                ])),
              ),
            ),
          );
        }),
        if (s.mode == 2) ...[ const SizedBox(height: 4), _SliderCard(label: '流水速度', icon: Icons.speed_rounded, value: s.flowSpeed.toDouble(), min: 1, max: 255, color: const Color(0xFF3B82F6), onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setFlowSpeed(iv); ble.setFlowSpeed(iv); }) ],
        if (s.mode == 1) ...[ const SizedBox(height: 4), _SliderCard(label: '呼吸周期', icon: Icons.timelapse_rounded, value: s.breathPeriod.toDouble(), min: 1, max: 255, color: const Color(0xFF06B6D4), onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBreathPeriod(iv); ble.setBreathPeriod(iv); }) ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _SceneTab extends ConsumerWidget {
  const _SceneTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final s = ref.watch(deviceProvider);
    final cs = Theme.of(context).colorScheme;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    final sceneIcons = [Icons.favorite_rounded, Icons.star_rounded, Icons.thumb_up_rounded, Icons.rocket_launch_rounded, Icons.emoji_emotions_rounded, Icons.local_fire_department_rounded, Icons.diamond_rounded, Icons.bolt_rounded];
    final sceneColors = [0xFFEF4444, 0xFFF97316, 0xFFEAB308, 0xFF22C55E, 0xFF06B6D4, 0xFF3B82F6, 0xFF8B5CF6, 0xFFEC4899];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('情景模式'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1, actions: const [_BleAction()]),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, 20), children: [
        const SizedBox(height: 4), const _BleBanner(), const SizedBox(height: 12),
        Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant), const SizedBox(width: 6), Text('轻点加载 · 长按保存', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))]),
        const SizedBox(height: 16),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.82),
          itemCount: 8,
          itemBuilder: (_, i) {
            final accent = Color(sceneColors[i]);
            final saved = s.sceneSaved.length > i && s.sceneSaved[i];
            return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: saved ? BorderSide(color: accent.withAlpha(120), width: 1.5) : BorderSide(color: cs.outlineVariant.withAlpha(60))),
              color: saved ? accent.withAlpha(15) : cs.surfaceContainerLow,
              child: InkWell(borderRadius: BorderRadius.circular(12),
                onTap: () => ble.loadScene(i),
                onLongPress: () { ble.saveScene(i); ref.read(deviceProvider.notifier).markSceneSaved(i); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存到场景 ${i+1}'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating)); },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: accent.withAlpha(saved ? 40 : 25)), child: Icon(sceneIcons[i], color: accent, size: 24)),
                    if (saved) Positioned(right: -2, top: -2, child: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, color: accent), child: const Icon(Icons.check_rounded, color: Colors.white, size: 12))),
                  ]),
                  const SizedBox(height: 8),
                  Text('场景 ${i+1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                ]),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}
