import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/ble_provider.dart';
import '../../theme/app_design.dart';
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
      builder: (context, connected, _) => AnimatedSwitcher(
        duration: AppMotion.normal,
        switchInCurve: AppMotion.standard,
        switchOutCurve: AppMotion.standard,
        child: connected
            ? const SizedBox.shrink(key: ValueKey('ble-connected'))
            : Material(
                key: const ValueKey('ble-offline'),
                color: cs.errorContainer.withAlpha(120),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerPage()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bluetooth_disabled_rounded,
                          size: 18,
                          color: cs.onErrorContainer,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            t.bleNotConnected,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onErrorContainer,
                                ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Flexible(
                          flex: 0,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              t.bleConnect,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onErrorContainer,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  child: Icon(
                    Icons.bluetooth_connected_rounded,
                    color: cs.primary,
                  ),
                )
              : Icon(
                  Icons.bluetooth_rounded,
                  color: cs.onSurfaceVariant.withAlpha(150),
                ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScannerPage()),
          ),
          onLongPress: connected
              ? () {
                  ble.queryStatus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(t.bleRefreshing),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }
}
