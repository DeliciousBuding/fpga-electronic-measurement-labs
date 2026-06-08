import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ble_diagnostics.dart';
import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/ble_provider.dart';
import '../theme/app_design.dart';
import 'shared/ble_widgets.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _advancedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final isZh = locale == null || locale.languageCode == 'zh';
    final ble = ref.read(bleServiceProvider);
    final t = AppLocalizations.of(context)!;
    final topPad =
        MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.sm;
    final bottomPad =
        MediaQuery.of(context).padding.bottom +
        kBottomNavigationBarHeight +
        AppSpacing.xl;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.navSettings), actions: const [BleAction()]),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topPad,
          AppSpacing.lg,
          bottomPad,
        ),
        children: [
          const BleBanner(),
          const SizedBox(height: AppSpacing.md),
          _SectionHeader(
            icon: Icons.brush_rounded,
            title: t.settingsAppearance,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.language_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.settingsLanguage,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              isZh ? t.settingsLangZh : t.settingsLangEn,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'zh',
                            label: Text(t.settingsLangZh),
                          ),
                          ButtonSegment(
                            value: 'en',
                            label: Text(t.settingsLangEn),
                          ),
                        ],
                        selected: {isZh ? 'zh' : 'en'},
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        onSelectionChanged: (v) => ref
                            .read(localeProvider.notifier)
                            .set(
                              v.first == 'zh'
                                  ? const Locale('zh')
                                  : const Locale('en'),
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xxl),
                  Row(
                    children: [
                      Icon(Icons.palette_rounded, size: 20, color: cs.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.settingsTheme,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              theme.mode == ThemeMode.light
                                  ? t.settingsThemeLight
                                  : theme.mode == ThemeMode.dark
                                  ? t.settingsThemeDark
                                  : t.settingsThemeSystem,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Icon(Icons.phone_android_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Icon(Icons.light_mode_rounded, size: 18),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Icon(Icons.dark_mode_rounded, size: 18),
                          ),
                        ],
                        selected: {theme.mode},
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        onSelectionChanged: (v) => ref
                            .read(themeProvider.notifier)
                            .setThemeMode(v.first),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionHeader(
            icon: Icons.bluetooth_rounded,
            title: t.settingsBluetooth,
          ),
          const SizedBox(height: AppSpacing.sm),
          _BleStatusCard(ble: ble),
          const SizedBox(height: AppSpacing.md),
          _AdvancedDiagnosticsCard(
            ble: ble,
            expanded: _advancedExpanded,
            onToggle: () =>
                setState(() => _advancedExpanded = !_advancedExpanded),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _SectionHeader(icon: Icons.info_rounded, title: t.settingsAbout),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: cs.primary,
                        ),
                        child: const Icon(
                          Icons.bluetooth_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.aboutAppName,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.aboutVersion,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.xxl),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: cs.onSurfaceVariant.withAlpha(150),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.aboutDesc,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _AdvancedDiagnosticsCard extends StatelessWidget {
  const _AdvancedDiagnosticsCard({
    required this.ble,
    required this.expanded,
    required this.onToggle,
  });

  final BLEService ble;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return ValueListenableBuilder<BleDiagnostics>(
      valueListenable: ble.diagnostics,
      builder: (context, diagnostics, _) {
        return Card(
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(
                        Icons.troubleshoot_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.diagnosticsTitle,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            _DiagnosticsSummary(
                              ble: ble,
                              diagnostics: diagnostics,
                              isZh: isZh,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _PhasePill(
                        text: isZh
                            ? diagnostics.phaseLabelZh
                            : diagnostics.phaseLabelEn,
                        ok: diagnostics.phase == BleDiagnosticPhase.ready,
                        failed: diagnostics.phase == BleDiagnosticPhase.failed,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.duration(context, AppMotion.normal),
                switchInCurve: AppMotion.curve(context, AppMotion.emphasized),
                switchOutCurve: AppMotion.curve(context, AppMotion.standard),
                child: expanded
                    ? _AdvancedDiagnosticsBody(
                        key: const ValueKey('advanced-diagnostics-open'),
                        ble: ble,
                        diagnostics: diagnostics,
                        isZh: isZh,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('advanced-diagnostics-closed'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DiagnosticsSummary extends StatelessWidget {
  const _DiagnosticsSummary({
    required this.ble,
    required this.diagnostics,
    required this.isZh,
  });

  final BLEService ble;
  final BleDiagnostics diagnostics;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder<int>(
      valueListenable: ble.debugLogVersion,
      builder: (context, value, _) {
        final protocolReady =
            diagnostics.targetServiceFound &&
            diagnostics.notifyCharacteristicFound &&
            diagnostics.notifyEnabled &&
            diagnostics.writeCharacteristicFound;
        final errorText = diagnostics.failureSummary.isEmpty
            ? t.diagnosticsNoError
            : diagnostics.failureSummary;
        final parts = [
          isZh ? diagnostics.phaseLabelZh : diagnostics.phaseLabelEn,
          'FFF0/1/2 ${protocolReady ? 'OK' : '--'}',
          t.debugLogCount(ble.debugLog.length),
        ];
        if (diagnostics.failureSummary.isNotEmpty) {
          parts.add(errorText);
        }
        return Text(
          parts.join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: diagnostics.failureSummary.isEmpty
                ? cs.onSurfaceVariant
                : cs.error,
          ),
        );
      },
    );
  }
}

class _AdvancedDiagnosticsBody extends StatelessWidget {
  const _AdvancedDiagnosticsBody({
    super.key,
    required this.ble,
    required this.diagnostics,
    required this.isZh,
  });

  final BLEService ble;
  final BleDiagnostics diagnostics;
  final bool isZh;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(40))),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DiagnosticRow(
              label: t.diagnosticsAdapter,
              value:
                  '${diagnostics.bleSupported == false ? t.bleNotSupported : 'BLE'} · ${diagnostics.adapterState ?? 'unknown'}',
            ),
            _DiagnosticRow(
              label: t.diagnosticsPhase,
              value: isZh ? diagnostics.phaseLabelZh : diagnostics.phaseLabelEn,
            ),
            _DiagnosticRow(
              label: t.diagnosticsScanCount,
              value: '${diagnostics.scanCount}',
            ),
            _DiagnosticRow(
              label: t.diagnosticsProtocol,
              value:
                  'FFF0 ${_mark(diagnostics.targetServiceFound)}  FFF1 ${_mark(diagnostics.notifyCharacteristicFound && diagnostics.notifyEnabled)}  FFF2 ${_mark(diagnostics.writeCharacteristicFound)}',
            ),
            _DiagnosticRow(
              label: t.diagnosticsLastError,
              value: diagnostics.failureSummary.isEmpty
                  ? t.diagnosticsNoError
                  : diagnostics.failureSummary,
              error: diagnostics.failureSummary.isNotEmpty,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () => ble.runSelfTest(),
                  icon: const Icon(Icons.health_and_safety_rounded, size: 18),
                  label: Text(t.diagnosticsRun),
                ),
                OutlinedButton.icon(
                  onPressed: ble.isConnected.value
                      ? () => ble.queryStatus()
                      : null,
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: Text(t.diagnosticsQuery),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: ble.exportDebugSnapshot()),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.diagnosticsCopied),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(t.diagnosticsCopy),
                ),
                TextButton.icon(
                  onPressed: ble.clearDebugLog,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(t.diagnosticsClear),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _InlineDebugLog(ble: ble),
          ],
        ),
      ),
    );
  }

  static String _mark(bool ok) => ok ? 'OK' : '--';
}

class _InlineDebugLog extends StatelessWidget {
  const _InlineDebugLog({required this.ble});

  final BLEService ble;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder<int>(
      valueListenable: ble.debugLogVersion,
      builder: (context, value, _) {
        final log = ble.debugLog;
        if (log.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: cs.surfaceContainerLowest,
            ),
            child: Text(
              t.debugLogEmpty,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          );
        }
        return Semantics(
          label: t.debugLogTitle,
          child: Container(
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              color: cs.surfaceContainerLowest,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: ListView.builder(
                primary: false,
                itemExtent: 17,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                itemCount: log.length,
                itemBuilder: (_, i) {
                  final idx = log.length - 1 - i;
                  final entry = log[idx];
                  final isTx = entry.startsWith('TX');
                  final isRx = entry.startsWith('RX');
                  return Text(
                    entry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isTx
                          ? cs.primary
                          : isRx
                          ? cs.tertiary
                          : cs.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  final String label;
  final String value;
  final bool error;
  const _DiagnosticRow({
    required this.label,
    required this.value,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: error ? cs.error : cs.onSurface,
                fontWeight: error ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhasePill extends StatelessWidget {
  final String text;
  final bool ok;
  final bool failed;
  const _PhasePill({
    required this.text,
    required this.ok,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = failed
        ? cs.error
        : ok
        ? cs.primary
        : cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withAlpha(18),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: connected
                          ? cs.primaryContainer
                          : cs.surfaceContainerLowest,
                    ),
                    child: Icon(
                      connected
                          ? Icons.bluetooth_connected_rounded
                          : Icons.bluetooth_disabled_rounded,
                      color: connected ? cs.primary : cs.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connected ? ble.deviceName : t.bleStatusOffline,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          connected
                              ? t.bleStatusDetailConnected
                              : t.bleStatusDetailDisconnected,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: connected
                          ? cs.primary.withAlpha(20)
                          : cs.outlineVariant.withAlpha(20),
                    ),
                    child: Text(
                      connected ? t.bleStatusConnected : t.bleStatusOffline,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: connected ? cs.primary : cs.onSurfaceVariant,
                      ),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
