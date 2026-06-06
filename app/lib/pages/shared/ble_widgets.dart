import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ble_provider.dart';
import '../scanner_page.dart';

class BleBanner extends ConsumerWidget {
  const BleBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (context, connected, _) => AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: connected
            ? const SizedBox.shrink()
            : Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.bluetooth_disabled_rounded, size: 20, color: cs.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.bleNotConnected,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600, color: cs.onErrorContainer))),
                    TextButton(
                        onPressed: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ScannerPage())),
                        style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            visualDensity: VisualDensity.compact),
                        child: Text(t.bleConnect,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700, color: cs.onErrorContainer))),
                  ]),
                ),
              ),
      ),
    );
  }
}

class BleAction extends ConsumerWidget {
  const BleAction({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ble = ref.read(bleServiceProvider);
    final cs = Theme.of(context).colorScheme;
    final t = AppLocalizations.of(context)!;
    return ValueListenableBuilder(
      valueListenable: ble.isConnected,
      builder: (context, connected, _) => Tooltip(
        message: connected
            ? t.bleTooltipConnected(ble.deviceName)
            : t.bleTooltipDisconnected,
        child: IconButton(
          icon: connected
              ? Badge(
                  isLabelVisible: true,
                  smallSize: 8,
                  child: Icon(Icons.bluetooth_connected_rounded, color: cs.primary))
              : Icon(Icons.bluetooth_rounded, color: cs.onSurfaceVariant.withAlpha(150)),
          onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const ScannerPage())),
          onLongPress: connected
              ? () {
                  ble.queryStatus();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(t.bleRefreshing),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ));
                }
              : null,
        ),
      ),
    );
  }
}
