import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final theme = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isZh = locale == null || locale.languageCode == 'zh';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('设置'), centerTitle: true, elevation: 0, scrolledUnderElevation: 1),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [cs.primaryContainer.withAlpha(60), cs.tertiaryContainer.withAlpha(40), cs.surface]),
        ),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 80, 16, 24), children: [
          _Section(label: '外观'),
          _Tile(icon: Icons.language_rounded, title: '语言 / Language', subtitle: isZh ? '中文' : 'English',
              trailing: SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'zh', label: Text('中文')), ButtonSegment(value: 'en', label: Text('EN'))],
                selected: {isZh ? 'zh' : 'en'},
                onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(v.first == 'zh' ? const Locale('zh') : const Locale('en')),
              )),
          _Tile(icon: Icons.palette_rounded, title: '主题模式',
              subtitle: theme.mode == ThemeMode.light ? '浅色' : theme.mode == ThemeMode.dark ? '深色' : '跟随系统',
              trailing: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Icon(Icons.phone_android_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.light, label: Icon(Icons.light_mode_rounded, size: 18)),
                  ButtonSegment(value: ThemeMode.dark, label: Icon(Icons.dark_mode_rounded, size: 18)),
                ],
                selected: {theme.mode},
                onSelectionChanged: (v) => ref.read(themeProvider.notifier).setThemeMode(v.first),
              )),
          const SizedBox(height: 20),
          _Section(label: '关于'),
          const _Tile(icon: Icons.info_rounded, title: 'RGB 彩灯蓝牙控制器', subtitle: 'v0.1 · C301 综合实验\n湖南大学 · 计算机学院实验中心'),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
    child: Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
  );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  const _Tile({required this.icon, required this.title, this.subtitle = '', this.trailing});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)) : null,
      trailing: trailing,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
