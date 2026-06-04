import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/ble_provider.dart';
import 'scanner_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final theme = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isZh = locale == null || locale.languageCode == 'zh';
    final ble = ref.read(bleServiceProvider);
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('设置'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1,
        actions: [Padding(padding: const EdgeInsets.only(right: 4), child: ValueListenableBuilder(valueListenable: ble.isConnected, builder: (_, connected, __) => IconButton(icon: connected ? Badge(isLabelVisible: true, smallSize: 8, child: Icon(Icons.bluetooth_connected_rounded, color: cs.primary)) : Icon(Icons.bluetooth_rounded, color: cs.onSurfaceVariant.withAlpha(150)), tooltip: connected ? '已连接 ${ble.deviceName}' : '未连接', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())))))],
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, 20), children: [
        _SectionHeader(icon: Icons.brush_rounded, title: '外观', cs: cs),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [Icon(Icons.language_rounded, size: 20, color: cs.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('语言', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 1), Text(isZh ? '中文' : 'English', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))])), SegmentedButton<String>(segments: const [ButtonSegment(value: 'zh', label: Text('中文')), ButtonSegment(value: 'en', label: Text('EN'))], selected: {isZh ? 'zh' : 'en'}, style: ButtonStyle(visualDensity: VisualDensity.compact, shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(v.first == 'zh' ? const Locale('zh') : const Locale('en')))]),
            const Divider(height: 24),
            Row(children: [Icon(Icons.palette_rounded, size: 20, color: cs.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('主题', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), const SizedBox(height: 1), Text(theme.mode == ThemeMode.light ? '浅色' : theme.mode == ThemeMode.dark ? '深色' : '跟随系统', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))])), SegmentedButton<ThemeMode>(segments: const [ButtonSegment(value: ThemeMode.system, label: Icon(Icons.phone_android_rounded, size: 18)), ButtonSegment(value: ThemeMode.light, label: Icon(Icons.light_mode_rounded, size: 18)), ButtonSegment(value: ThemeMode.dark, label: Icon(Icons.dark_mode_rounded, size: 18))], selected: {theme.mode}, style: ButtonStyle(visualDensity: VisualDensity.compact, shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), onSelectionChanged: (v) => ref.read(themeProvider.notifier).setThemeMode(v.first))]),
          ])),
        ),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.info_rounded, title: '关于', cs: cs),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.primary), child: const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('RGB 彩灯蓝牙控制器', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text('v0.1 · 湖南大学 · 工训中心', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ])),
            ]),
            const Divider(height: 28),
            Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant.withAlpha(150)), const SizedBox(width: 8), Expanded(child: Text('基于 CH9143 BLE 模块 + FPGA Cyclone IV E 控制 WS2812 RGB 彩灯', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)))]),
          ])),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title; final ColorScheme cs;
  const _SectionHeader({required this.icon, required this.title, required this.cs});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(left: 4), child: Row(children: [Icon(icon, size: 18, color: cs.primary), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: cs.onSurface))]));
}
