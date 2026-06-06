import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../l10n/app_localizations.dart';
import '../providers/ble_provider.dart';

class ScannerPage extends ConsumerStatefulWidget {
  const ScannerPage({super.key});
  @override
  ConsumerState<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends ConsumerState<ScannerPage> with SingleTickerProviderStateMixin {
  List<ScanResult> _devices = [];
  bool _scanning = false;
  String? _connectingId;
  bool _bleOff = false;
  StreamSubscription? _adapterSub;
  late AnimationController _pulse;
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _ringCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _checkAdapter();
    _adapterSub = FlutterBluePlus.adapterState.listen((s) { if (!mounted) return; if (s == BluetoothAdapterState.on) { setState(() => _bleOff = false); _startScan(); } else { setState(() => _bleOff = true); } });
  }

  @override
  void dispose() { _pulse.dispose(); _ringCtrl.dispose(); _adapterSub?.cancel(); super.dispose(); }

  Future<void> _checkAdapter() async {
    try { final s = await FlutterBluePlus.adapterState.first; if (mounted) setState(() => _bleOff = s != BluetoothAdapterState.on); } catch (_) {}
  }

  Future<void> _startScan() async {
    if (_scanning || _bleOff) return;
    setState(() => _scanning = true);
    try { final r = await ref.read(bleServiceProvider).scan(seconds: 5); if (mounted) setState(() => _devices = r); }
    finally { if (mounted) setState(() => _scanning = false); }
  }

  Future<void> _connect(ScanResult r) async {
    setState(() => _connectingId = r.device.remoteId.str);
    final ok = await ref.read(bleServiceProvider).connect(r.device);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) { Navigator.pop(context, true); }
    else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.scanConnectFail), behavior: SnackBarBehavior.floating)); }
  }

  String _name(ScanResult r) => r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.remoteId.str;
  Color _rssi(int dbm) { if (dbm > -50) return const Color(0xFF22C55E); if (dbm > -70) return const Color(0xFFEAB308); return const Color(0xFFEF4444); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    if (_bleOff) return _buildBleOff(context, cs, t, topPad);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.scanTitle), ),
      body: Column(children: [
        SizedBox(height: topPad),
        SizedBox(height: 140, child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(animation: _ringCtrl, builder: (_, child) => Transform.scale(scale: 1.0 + _ringCtrl.value * 0.3, child: Opacity(opacity: 1.0 - _ringCtrl.value, child: child)), child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary.withAlpha(40), width: 2)))),
          AnimatedBuilder(animation: _ringCtrl, builder: (_, child) => Transform.scale(scale: 1.0 + _ringCtrl.value * 0.2 + 0.1, child: Opacity(opacity: 0.6 - _ringCtrl.value * 0.3, child: child)), child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary.withAlpha(60), width: 2)))),
          AnimatedBuilder(animation: _pulse, builder: (_, child) => Transform.scale(scale: 1.0 + _pulse.value * 0.06, child: child), child: Container(width: 64, height: 64, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cs.primaryContainer, boxShadow: [BoxShadow(color: cs.primary.withAlpha(40), blurRadius: 20, spreadRadius: 4)]), child: Icon(Icons.bluetooth_searching_rounded, size: 32, color: cs.primary))),
        ])),
        const SizedBox(height: 8),
        Text(t.scanTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(t.scanHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        Expanded(child: _devices.isEmpty
            ? Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _scanning
                ? Column(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary)), const SizedBox(height: 18), Text(t.scanScanning, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant))])
                : Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 72, height: 72, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cs.surfaceContainerLow), child: Icon(Icons.bluetooth_searching_rounded, size: 36, color: cs.onSurfaceVariant.withAlpha(100))), const SizedBox(height: 16), Text(t.scanNoDevice, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)), const SizedBox(height: 6), Text(t.scanRetryHint, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant.withAlpha(150)))])))
            : ListView.separated(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), itemCount: _devices.length, separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final d = _devices[i]; final loading = _connectingId == d.device.remoteId.str;
                  return Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: loading ? null : () => _connect(d),
                      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                        Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.primaryContainer), child: loading ? Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary))) : Icon(Icons.devices_rounded, color: cs.primary, size: 22)),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_name(d), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 2), Text(d.device.remoteId.str, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))])),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _rssi(d.rssi).withAlpha(20)), child: Text('${d.rssi} dBm', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: _rssi(d.rssi)))),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withAlpha(120)),
                      ]))),
                  );
                })),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 16), child: SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: _scanning || _bleOff ? null : _startScan, icon: const Icon(Icons.refresh_rounded, size: 20), label: Text(_scanning ? t.scanScanningBtn : t.scanRescan), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))))),
      ]),
    );
  }

  Widget _buildBleOff(BuildContext context, ColorScheme cs, AppLocalizations t, double topPad) => Scaffold(
    extendBodyBehindAppBar: true,
    appBar: AppBar(title: Text(t.scanTitle), ),
    body: Column(children: [
      SizedBox(height: topPad + 40), const Spacer(),
      Container(width: 96, height: 96, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: cs.surfaceContainerLow), child: Icon(Icons.bluetooth_disabled_rounded, size: 48, color: cs.onSurfaceVariant.withAlpha(100))),
      const SizedBox(height: 20), Text(t.bleOffTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)), const SizedBox(height: 6), Text(t.bleOffHint, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant.withAlpha(150))),
      const SizedBox(height: 28),
      OutlinedButton.icon(onPressed: () => FlutterBluePlus.turnOn(), icon: const Icon(Icons.bluetooth_rounded, size: 20), label: Text(t.bleTurnOn), style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
      const Spacer(flex: 2),
    ]),
  );
}
