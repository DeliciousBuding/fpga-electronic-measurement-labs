import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../providers/device_provider.dart';
import '../providers/preferences_provider.dart';
import '../utils/colors.dart';
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
      body: IndexedStack(
        index: _index,
        children: const [_ColorTab(), _EffectTab(), _SceneTab(), SettingsPage()],
      ),
      bottomNavigationBar: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visibility,
          child: Opacity(
            opacity: visibility,
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) {
                ref.read(barVisibilityProvider.notifier).show();
                setState(() => _index = i);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.palette_outlined), selectedIcon: Icon(Icons.palette_rounded), label: '颜色'),
                NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome_rounded), label: '灯效'),
                NavigationDestination(icon: Icon(Icons.bookmark_outlined), selectedIcon: Icon(Icons.bookmark_rounded), label: '情景'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: '设置'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---- 颜色 ----
class _ColorTab extends ConsumerWidget {
  const _ColorTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final color = Color.fromARGB(255, s.r, s.g, s.b);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('RGB Controller'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
      body: Container(
        decoration: BoxDecoration(gradient: _bg(cs)),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 80, 20, 24), children: [
          Center(
            child: AnimatedContainer(duration: const Duration(milliseconds: 400),
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                boxShadow: [BoxShadow(color: color.withAlpha(160), blurRadius: 56, spreadRadius: 12)],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(child: Text('RGB (${s.r}, ${s.g}, ${s.b})', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(height: 28),
          _Label('亮度'),
          Slider(value: s.brightness.toDouble(), min: 1, max: 255, activeColor: cs.primary,
              onChangeEnd: (_) {},
              onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBrightness(iv); ble.setBrightness(iv); }),
          _Label('通道'),
          _Sliders(r: s.r, g: s.g, b: s.b, cs: cs,
              onR: (v) { ref.read(deviceProvider.notifier).setColor(v, s.g, s.b); ble.setColor(v, s.g, s.b); },
              onG: (v) { ref.read(deviceProvider.notifier).setColor(s.r, v, s.b); ble.setColor(s.r, v, s.b); },
              onB: (v) { ref.read(deviceProvider.notifier).setColor(s.r, s.g, v); ble.setColor(s.r, s.g, v); }),
          const SizedBox(height: 16),
          _Label('预设颜色'),
          const SizedBox(height: 10),
          Wrap(spacing: 12, runSpacing: 12, children: presetColors.map((e) {
            final cl = Color(e.$1);
            return GestureDetector(
              onTap: () { ref.read(deviceProvider.notifier).setColor((cl.r*255).round(), (cl.g*255).round(), (cl.b*255).round()); ble.setColor((cl.r*255).round(), (cl.g*255).round(), (cl.b*255).round()); },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cl, boxShadow: [BoxShadow(color: cl.withAlpha(80), blurRadius: 12, spreadRadius: 2)], border: Border.all(color: cs.outlineVariant.withAlpha(100))),
              ),
            );
          }).toList()),
        ]),
      ),
    );
  }
}

LinearGradient _bg(ColorScheme cs) => LinearGradient(
  begin: Alignment.topLeft, end: Alignment.bottomRight,
  colors: [cs.primaryContainer.withAlpha(60), cs.tertiaryContainer.withAlpha(40), cs.surface],
);

class _Label extends StatelessWidget {
  final String t;
  const _Label(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
  );
}

class _Sliders extends StatelessWidget {
  final int r, g, b;
  final ColorScheme cs;
  final ValueChanged<int> onR, onG, onB;
  const _Sliders({required this.r, required this.g, required this.b, required this.cs, required this.onR, required this.onG, required this.onB});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _Row('R', r, const Color(0xFFEF5350), onR, cs),
      _Row('G', g, const Color(0xFF66BB6A), onG, cs),
      _Row('B', b, const Color(0xFF42A5F5), onB, cs),
    ]);
  }
}

class _Row extends StatelessWidget {
  final String l; final int v; final Color c; final ValueChanged<int> onC; final ColorScheme cs;
  const _Row(this.l, this.v, this.c, this.onC, this.cs);
  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 22, child: Text(l, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: c))),
    Expanded(child: SliderTheme(data: SliderThemeData(trackHeight: 5, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9), activeTrackColor: c, inactiveTrackColor: c.withAlpha(40), thumbColor: c, overlayColor: c.withAlpha(25)), child: Slider(value: v.toDouble(), min: 0, max: 255, onChanged: (x) => onC(x.round())))),
    SizedBox(width: 36, child: Text('$v', textAlign: TextAlign.end, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant))),
  ]);
}

// ---- 灯效 ----
class _EffectTab extends ConsumerWidget {
  const _EffectTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceProvider);
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;

    final items = [
      (0, '静态', Icons.light_mode_rounded, '固定颜色常亮'),
      (1, '呼吸', Icons.air_rounded, '正弦包络周期明暗'),
      (2, '流水', Icons.waves_rounded, '灯光逐位移动'),
      (3, '渐变', Icons.gradient_rounded, 'HSV 色相平滑过渡'),
      (4, '音乐', Icons.music_note_rounded, '随音频节拍律动'),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('灯效'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
      body: Container(
        decoration: BoxDecoration(gradient: _bg(cs)),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 80, 20, 24), children: [
          ...items.map((m) {
            final sel = s.mode == m.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: sel ? cs.primaryContainer : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () { ref.read(deviceProvider.notifier).setMode(m.$1); ble.setMode(m.$1); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(children: [
                      Icon(m.$3, color: sel ? cs.primary : cs.onSurfaceVariant, size: 28),
                      const SizedBox(width: 16),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.$2, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: sel ? cs.onPrimaryContainer : cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(m.$4, style: TextStyle(fontSize: 12, color: sel ? cs.onPrimaryContainer.withAlpha(180) : cs.onSurfaceVariant)),
                      ])),
                      if (sel) Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
                    ]),
                  ),
                ),
              ),
            );
          }),
          if (s.mode == 2) ...[
            const SizedBox(height: 8),
            _Label('流水速度'),
            Slider(value: s.flowSpeed.toDouble(), min: 1, max: 255, activeColor: cs.primary, onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setFlowSpeed(iv); ble.setFlowSpeed(iv); }),
          ],
          if (s.mode == 1) ...[
            const SizedBox(height: 8),
            _Label('呼吸周期'),
            Slider(value: s.breathPeriod.toDouble(), min: 1, max: 255, activeColor: cs.primary, onChanged: (v) { final iv = v.round(); ref.read(deviceProvider.notifier).setBreathPeriod(iv); ble.setBreathPeriod(iv); }),
          ],
        ]),
      ),
    );
  }
}

// ---- 情景 ----
class _SceneTab extends ConsumerWidget {
  const _SceneTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('情景模式'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
      body: Container(
        decoration: BoxDecoration(gradient: _bg(cs)),
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 80, 20, 24), children: [
          Text('最多保存 8 组场景', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          Text('轻点加载 · 长按保存', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85),
            itemCount: 8,
            itemBuilder: (_, i) => Material(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => ble.loadScene(i),
                onLongPress: () { ble.saveScene(i); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已保存到场景 ${i+1}'), duration: const Duration(seconds: 1))); },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.bookmark_rounded, color: cs.primary, size: 28),
                  const SizedBox(height: 6),
                  Text('场景 ${i+1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
