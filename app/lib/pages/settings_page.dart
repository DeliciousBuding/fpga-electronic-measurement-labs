import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/ble_provider.dart';
import 'scanner_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _debugExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isZh = locale == null || locale.languageCode == 'zh';
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    final bottomPad = MediaQuery.of(context).padding.bottom + kBottomNavigationBarHeight + 20;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t.navSettings), centerTitle: false, elevation: 0, scrolledUnderElevation: 1,
        actions: [Padding(padding: const EdgeInsets.only(right: 4), child: ValueListenableBuilder(valueListenable: ble.isConnected, builder: (context, connected, _) => IconButton(icon: connected ? Badge(isLabelVisible: true, smallSize: 8, child: Icon(Icons.bluetooth_connected_rounded, color: cs.primary)) : Icon(Icons.bluetooth_rounded, color: cs.onSurfaceVariant.withAlpha(150)), tooltip: connected ? t.bleTooltipConnected(ble.deviceName) : t.bleTooltipDisconnected, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerPage())))))],
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(20, topPad, 20, bottomPad), children: [
        _SectionHeader(icon: Icons.brush_rounded, title: t.settingsAppearance),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [Icon(Icons.language_rounded, size: 20, color: cs.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.settingsLanguage, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 1), Text(isZh ? t.settingsLangZh : 'English', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))])), SegmentedButton<String>(segments: [ButtonSegment(value: 'zh', label: Text(t.settingsLangZh)), const ButtonSegment(value: 'en', label: Text('EN'))], selected: {isZh ? 'zh' : 'en'}, style: ButtonStyle(visualDensity: VisualDensity.compact, shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), onSelectionChanged: (v) => ref.read(localeProvider.notifier).set(v.first == 'zh' ? const Locale('zh') : const Locale('en')))]),
            const Divider(height: 24),
            Row(children: [Icon(Icons.palette_rounded, size: 20, color: cs.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.settingsTheme, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 1), Text(theme.mode == ThemeMode.light ? t.settingsThemeLight : theme.mode == ThemeMode.dark ? t.settingsThemeDark : t.settingsThemeSystem, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))])), SegmentedButton<ThemeMode>(segments: const [ButtonSegment(value: ThemeMode.system, label: Icon(Icons.phone_android_rounded, size: 18)), ButtonSegment(value: ThemeMode.light, label: Icon(Icons.light_mode_rounded, size: 18)), ButtonSegment(value: ThemeMode.dark, label: Icon(Icons.dark_mode_rounded, size: 18))], selected: {theme.mode}, style: ButtonStyle(visualDensity: VisualDensity.compact, shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))), onSelectionChanged: (v) => ref.read(themeProvider.notifier).setThemeMode(v.first))]),
          ])),
        ),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.bluetooth_rounded, title: t.settingsBluetooth),
        const SizedBox(height: 8),
        _BleStatusCard(ble: ble),
        const SizedBox(height: 12),
        _DebugLogCard(ble: ble, expanded: _debugExpanded, onToggle: () => setState(() => _debugExpanded = !_debugExpanded)),
        const SizedBox(height: 24),
        _SectionHeader(icon: Icons.info_rounded, title: t.settingsAbout),
        const SizedBox(height: 8),
        Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.primary), child: const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.aboutAppName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(t.aboutVersion, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ])),
            ]),
            const Divider(height: 28),
            Row(children: [Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurfaceVariant.withAlpha(150)), const SizedBox(width: 8), Expanded(child: Text(t.aboutDesc, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)))]),
          ])),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _BleStatusCard extends StatelessWidget {
  final BLEService ble;
  const _BleStatusCard({required this.ble});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: ble.isConnected,
      builder: (context, connected, _) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: connected ? cs.primaryContainer : cs.surfaceContainerLowest), child: Icon(connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded, color: connected ? cs.primary : cs.onSurfaceVariant, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(connected ? ble.deviceName : t.bleStatusOffline, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
              const SizedBox(height: 1),
              Text(connected ? t.bleStatusDetailConnected : t.bleStatusDetailDisconnected, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ])),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: connected ? cs.primary.withAlpha(20) : cs.outlineVariant.withAlpha(20)), child: Text(connected ? t.bleStatusConnected : t.bleStatusOffline, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: connected ? cs.primary : cs.onSurfaceVariant))),
          ]),
        ])),
      ),
    );
  }
}

class _DebugLogCard extends StatelessWidget {
  final BLEService ble;
  final bool expanded;
  final VoidCallback onToggle;
  const _DebugLogCard({required this.ble, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        InkWell(
          borderRadius: expanded ? const BorderRadius.vertical(top: Radius.circular(12)) : BorderRadius.circular(12),
          onTap: onToggle,
          child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
            Icon(Icons.terminal_rounded, size: 20, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(child: ValueListenableBuilder<int>(
              valueListenable: ble.debugLogVersion,
              builder: (context, value, _) {
                final count = ble.debugLog.length;
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.debugLogTitle, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  const SizedBox(height: 1),
                  Text(t.debugLogCount(count), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]);
              },
            )),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: cs.onSurfaceVariant),
          ])),
        ),
        if (expanded) ValueListenableBuilder<int>(
          valueListenable: ble.debugLogVersion,
          builder: (context, value, _) {
            final log = ble.debugLog;
            if (log.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(t.debugLogEmpty, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)));
            return Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(40)))),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: log.length,
                itemBuilder: (_, i) {
                  final idx = log.length - 1 - i;
                  final entry = log[idx];
                  final isTx = entry.startsWith('TX');
                  final isRx = entry.startsWith('RX');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(entry, style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isTx ? cs.primary : isRx ? cs.tertiary : cs.onSurfaceVariant,
                    )),
                  );
                },
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.only(left: 4), child: Row(children: [Icon(icon, size: 18, color: cs.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface))]));
  }
}
