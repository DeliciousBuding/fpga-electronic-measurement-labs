import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_design.dart';
import '../../utils/ble_scan_matcher.dart';

String scanResultName(ScanResult result) => scanResultDisplayName(result);

class ScanDeviceViewData {
  const ScanDeviceViewData({
    required this.name,
    required this.id,
    required this.rssi,
    required this.likelyTarget,
  });

  factory ScanDeviceViewData.fromScanResult(ScanResult result) {
    return ScanDeviceViewData(
      name: scanResultDisplayName(result),
      id: result.device.remoteId.str,
      rssi: result.rssi,
      likelyTarget: scanResultLooksLikeTarget(result),
    );
  }

  final String name;
  final String id;
  final int rssi;
  final bool likelyTarget;
}

Color rssiColor(int dbm) {
  if (dbm > -50) return const Color(0xFF22C55E);
  if (dbm > -70) return const Color(0xFFEAB308);
  return const Color(0xFFEF4444);
}

class ScannerHeader extends StatelessWidget {
  const ScannerHeader({
    super.key,
    required this.pulse,
    required this.ring,
    required this.active,
  });

  final Animation<double> pulse;
  final Animation<double> ring;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (active)
                AnimatedBuilder(
                  animation: ring,
                  builder: (_, child) => Transform.scale(
                    scale: 1.0 + ring.value * 0.3,
                    child: Opacity(opacity: 1.0 - ring.value, child: child),
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withAlpha(40),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              if (active)
                AnimatedBuilder(
                  animation: ring,
                  builder: (_, child) => Transform.scale(
                    scale: 1.1 + ring.value * 0.2,
                    child: Opacity(
                      opacity: 0.6 - ring.value * 0.3,
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cs.primary.withAlpha(60),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: pulse,
                builder: (_, child) => Transform.scale(
                  scale: active ? 1.0 + pulse.value * 0.06 : 1.0,
                  child: child,
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: cs.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withAlpha(40),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.bluetooth_searching_rounded,
                    size: 32,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.scanTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          t.scanHint,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class ScanEmptyState extends StatelessWidget {
  const ScanEmptyState({super.key, required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Center(
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context, AppMotion.normal),
        switchInCurve: AppMotion.curve(context, AppMotion.emphasized),
        switchOutCurve: AppMotion.curve(context, AppMotion.standard),
        child: scanning
            ? Column(
                key: const ValueKey('scanning'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.scanScanning,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('empty'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: cs.surfaceContainerLow,
                    ),
                    child: Icon(
                      Icons.bluetooth_searching_rounded,
                      size: 36,
                      color: cs.onSurfaceVariant.withAlpha(100),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t.scanNoDevice,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.scanRetryHint,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class ScanDeviceTile extends StatelessWidget {
  const ScanDeviceTile({
    super.key,
    required this.device,
    required this.loading,
    required this.onTap,
  });

  final ScanDeviceViewData device;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final signalColor = rssiColor(device.rssi);
    final likelyTarget = device.likelyTarget;
    return Card(
      color: likelyTarget ? cs.primaryContainer.withAlpha(90) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: likelyTarget
            ? BorderSide(color: cs.primary.withAlpha(120), width: 1.4)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: cs.primaryContainer,
                ),
                child: loading
                    ? Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: cs.primary,
                          ),
                        ),
                      )
                    : Icon(Icons.devices_rounded, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: likelyTarget ? cs.primary : cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 108),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (likelyTarget) ...[
                        Tooltip(
                          message: 'CH9143 / FFF0',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: cs.primary.withAlpha(22),
                            ),
                            child: Text(
                              'RGB',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.primary,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: signalColor.withAlpha(20),
                        ),
                        child: Text(
                          '${device.rssi} dBm',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: signalColor,
                              ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant.withAlpha(120),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BleOffState extends StatelessWidget {
  const BleOffState({super.key, required this.topPad});

  final double topPad;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(t.scanTitle)),
      body: Column(
        children: [
          SizedBox(height: topPad + 40),
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.surfaceContainerLow,
            ),
            child: Icon(
              Icons.bluetooth_disabled_rounded,
              size: 48,
              color: cs.onSurfaceVariant.withAlpha(100),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t.bleOffTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            t.bleOffHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant.withAlpha(150),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: kIsWeb ? null : () => FlutterBluePlus.turnOn(),
            icon: const Icon(Icons.bluetooth_rounded, size: 20),
            label: Text(t.bleTurnOn),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
