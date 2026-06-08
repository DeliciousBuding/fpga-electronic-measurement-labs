import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../l10n/app_localizations.dart';
import '../models/ble_diagnostics.dart';
import '../providers/ble_provider.dart';
import '../theme/app_design.dart';
import 'shared/scanner_widgets.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({
    super.key,
    this.adapterStateStream,
    this.readInitialAdapterState,
    this.autoScanOnAdapterOn = !kIsWeb,
  });

  final Stream<BluetoothAdapterState>? adapterStateStream;
  final Future<BluetoothAdapterState> Function()? readInitialAdapterState;
  final bool autoScanOnAdapterOn;

  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage>
    with TickerProviderStateMixin {
  List<ScanResult> _devices = [];
  bool _usingDebugDevices = false;
  bool _scanning = false;
  bool _scanCompleted = false;
  String? _connectingId;
  bool _bleOff = false;
  StreamSubscription? _adapterSub;
  late AnimationController _pulse;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _checkAdapter();
    _adapterSub = (widget.adapterStateStream ?? FlutterBluePlus.adapterState)
        .listen((s) {
          if (!mounted) return;
          if (s == BluetoothAdapterState.on) {
            setState(() => _bleOff = false);
            if (widget.autoScanOnAdapterOn) _startScan();
          } else {
            setState(() => _bleOff = true);
          }
        });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _ringCtrl.dispose();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> _checkAdapter() async {
    try {
      final s =
          await (widget.readInitialAdapterState?.call() ??
              FlutterBluePlus.adapterState.first);
      if (mounted) setState(() => _bleOff = s != BluetoothAdapterState.on);
    } catch (_) {}
  }

  Future<void> _startScan() async {
    if (_scanning || _bleOff) return;
    setState(() {
      _scanCompleted = false;
      _usingDebugDevices = false;
    });
    _setScanning(true);
    try {
      final r = await ref.read(bleServiceProvider).scan(seconds: 5);
      if (mounted) {
        setState(() {
          _devices = r;
          _scanCompleted = true;
        });
      }
    } finally {
      if (mounted) _setScanning(false);
    }
  }

  void _showDebugDevices() {
    if (!kDebugMode || _scanning) return;
    _setScanning(false);
    setState(() {
      _devices = [];
      _usingDebugDevices = true;
      _scanCompleted = false;
    });
  }

  void _setScanning(bool value) {
    if (!mounted) return;
    setState(() => _scanning = value);
    if (AppMotion.reduced(context)) {
      _pulse.stop();
      _ringCtrl.stop();
      _pulse.value = 0;
      _ringCtrl.value = 0;
      return;
    }
    if (value) {
      _pulse.repeat(reverse: true);
      _ringCtrl.repeat();
    } else {
      _pulse.stop();
      _ringCtrl.stop();
      _pulse.animateTo(
        0,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.curve(context, AppMotion.standard),
      );
      _ringCtrl.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scanning) _setScanning(true);
  }

  Future<void> _connect(ScanResult r) async {
    setState(() => _connectingId = r.device.remoteId.str);
    final ok = await ref.read(bleServiceProvider).connect(r.device);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.scanConnectFail),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showDebugDeviceNotice(ScanDeviceViewData device) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isZh
              ? '这是调试样例：${device.name}，不会连接真实硬件'
              : 'Debug sample only: ${device.name}, no hardware connection',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    if (_bleOff) return BleOffState(topPad: topPad);
    final debugDevices = _usingDebugDevices
        ? _debugScanDevices
        : const <ScanDeviceViewData>[];
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(t.scanTitle),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: Localizations.localeOf(context).languageCode == 'zh'
                  ? '载入调试样例'
                  : 'Load debug samples',
              onPressed: _scanning ? null : _showDebugDevices,
              icon: const Icon(Icons.science_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: topPad),
          ScannerHeader(pulse: _pulse, ring: _ringCtrl, active: _scanning),
          _ScanDiagnosticsPanel(
            ble: ref.read(bleServiceProvider),
            connecting: _connectingId != null,
            forceVisible: _scanning || _scanCompleted,
          ),
          Expanded(
            child: _devices.isEmpty && debugDevices.isEmpty
                ? ScanEmptyState(scanning: _scanning)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _usingDebugDevices
                        ? debugDevices.length
                        : _devices.length,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (_usingDebugDevices) {
                        final d = debugDevices[i];
                        return ScanDeviceTile(
                          device: d,
                          loading: false,
                          onTap: () => _showDebugDeviceNotice(d),
                        );
                      }
                      final d = _devices[i];
                      final loading = _connectingId == d.device.remoteId.str;
                      return ScanDeviceTile(
                        device: ScanDeviceViewData.fromScanResult(d),
                        loading: loading,
                        onTap: () => _connect(d),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _scanning || _bleOff ? null : _startScan,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(_scanning ? t.scanScanningBtn : t.scanRescan),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _debugScanDevices = <ScanDeviceViewData>[
  ScanDeviceViewData(
    name: 'CH9143 RGB Controller',
    id: 'D0:39:72:FF:F0:12',
    rssi: -44,
    likelyTarget: true,
  ),
  ScanDeviceViewData(
    name: 'UART-FFF0-LED',
    id: 'C3:01:24:06:06:01',
    rssi: -61,
    likelyTarget: true,
  ),
  ScanDeviceViewData(
    name: 'Living Room Speaker',
    id: 'A8:20:4F:92:13:BC',
    rssi: -49,
    likelyTarget: false,
  ),
  ScanDeviceViewData(
    name: 'BLE Thermometer',
    id: '88:EE:10:55:21:9A',
    rssi: -72,
    likelyTarget: false,
  ),
];

class _ScanDiagnosticsPanel extends StatelessWidget {
  const _ScanDiagnosticsPanel({
    required this.ble,
    required this.connecting,
    required this.forceVisible,
  });

  final BLEService ble;
  final bool connecting;
  final bool forceVisible;

  @override
  Widget build(BuildContext context) {
    final isZh = Localizations.localeOf(context).languageCode == 'zh';
    return ValueListenableBuilder<BleDiagnostics>(
      valueListenable: ble.diagnostics,
      builder: (context, diagnostics, _) {
        final visible =
            forceVisible ||
            connecting ||
            diagnostics.scanInProgress ||
            diagnostics.phase == BleDiagnosticPhase.failed ||
            diagnostics.failureSummary.isNotEmpty;
        return AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.normal),
          switchInCurve: AppMotion.curve(context, AppMotion.emphasized),
          switchOutCurve: AppMotion.curve(context, AppMotion.standard),
          child: visible
              ? _ScanDiagnosticsCard(
                  key: const ValueKey('scan-diagnostics-visible'),
                  ble: ble,
                  diagnostics: diagnostics,
                  isZh: isZh,
                )
              : const SizedBox.shrink(key: ValueKey('scan-diagnostics-hidden')),
        );
      },
    );
  }
}

class _ScanDiagnosticsCard extends StatelessWidget {
  const _ScanDiagnosticsCard({
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
    final failed = diagnostics.failureSummary.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: failed
              ? cs.errorContainer.withAlpha(150)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: failed
                ? cs.error.withAlpha(70)
                : cs.outlineVariant.withAlpha(70),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.bluetooth_connected_rounded,
                    size: 20,
                    color: failed ? cs.error : cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      t.diagnosticsTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton.icon(
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
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: Text(t.diagnosticsCopy),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _ScanDiagnosticLine(
                label: t.diagnosticsPhase,
                value: isZh
                    ? diagnostics.phaseLabelZh
                    : diagnostics.phaseLabelEn,
                error: failed,
              ),
              _ScanDiagnosticLine(
                label: t.diagnosticsScanCount,
                value: diagnostics.scanInProgress
                    ? t.scanScanning
                    : '${diagnostics.scanCount}',
                error: failed,
              ),
              _ScanDiagnosticLine(
                label: t.diagnosticsProtocol,
                value:
                    'FFF0 ${_mark(diagnostics.targetServiceFound)}  FFF1 ${_mark(diagnostics.notifyCharacteristicFound && diagnostics.notifyEnabled)}  FFF2 ${_mark(diagnostics.writeCharacteristicFound)}',
                error: failed,
              ),
              if (failed)
                _ScanDiagnosticLine(
                  label: t.diagnosticsLastError,
                  value: diagnostics.failureSummary,
                  error: true,
                  maxLines: 3,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _mark(bool ok) => ok ? 'OK' : '--';
}

class _ScanDiagnosticLine extends StatelessWidget {
  const _ScanDiagnosticLine({
    required this.label,
    required this.value,
    this.error = false,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final bool error;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: error ? cs.error : cs.onSurface,
                fontWeight: error ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
