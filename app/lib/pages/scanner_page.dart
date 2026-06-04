import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
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
  StreamSubscription? _adapterSub;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _startScan();
    _adapterSub = FlutterBluePlus.adapterState.listen((s) { if (s == BluetoothAdapterState.on && mounted) _startScan(); });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _adapterSub?.cancel();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final r = await ref.read(bleServiceProvider).scan(seconds: 5);
      if (mounted) { setState(() => _devices = r); }
    } finally {
      if (mounted) { setState(() => _scanning = false); }
    }
  }

  Future<void> _connect(ScanResult r) async {
    setState(() => _connectingId = r.device.remoteId.str);
    final ok = await ref.read(bleServiceProvider).connect(r.device);
    if (!mounted) return;
    setState(() => _connectingId = null);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('连接失败，请重试')));
    }
  }

  String _name(ScanResult r) => r.advertisementData.advName.isNotEmpty ? r.advertisementData.advName : r.device.remoteId.str;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('扫描蓝牙设备'), centerTitle: true, elevation: 0),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primaryContainer.withAlpha(60), cs.tertiaryContainer.withAlpha(40), cs.surface])),
        child: Column(children: [
          const SizedBox(height: 80),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.scale(scale: 1.0 + _pulse.value * 0.08, child: child),
            child: Icon(Icons.bluetooth_searching_rounded, size: 64, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text('扫描蓝牙设备', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('请确保 CH9143 BLE 模块已上电', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 28),
          Expanded(
            child: _devices.isEmpty
                ? Center(child: _scanning ? const CircularProgressIndicator() : Text('未发现设备', style: TextStyle(color: cs.onSurfaceVariant)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _devices.length, separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = _devices[i];
                      final loading = _connectingId == d.device.remoteId.str;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: cs.primaryContainer, child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.bluetooth, color: cs.onPrimaryContainer)),
                          title: Text(_name(d), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('RSSI: ${d.rssi} dBm  |  ${d.device.remoteId.str}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                          trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                          onTap: loading ? null : () => _connect(d),
                        ),
                      );
                    }),
          ),
          SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: _scanning ? null : _startScan, icon: const Icon(Icons.refresh_rounded), label: Text(_scanning ? '扫描中...' : '重新扫描'), style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))))),
        ]),
      ),
    );
  }
}
