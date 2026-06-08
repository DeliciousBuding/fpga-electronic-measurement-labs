import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/providers/device_provider.dart';
import 'package:rgb_ble_controller/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('loads and persists saved scene slots', () async {
    SharedPreferences.setMockInitialValues({
      'device_scene_saved': ['1', '0', '0', '1', '0', '0', '0', '0'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(deviceProvider).sceneSaved, [
      true,
      false,
      false,
      true,
      false,
      false,
      false,
      false,
    ]);

    await container.read(deviceProvider.notifier).markSceneSaved(6);

    expect(prefs.getStringList('device_scene_saved'), [
      '1',
      '0',
      '0',
      '1',
      '0',
      '0',
      '1',
      '0',
    ]);
  });

  test('tracks active scene without persisting it as a saved slot', () async {
    SharedPreferences.setMockInitialValues({
      'device_scene_saved': ['0', '0', '0', '0', '0', '0', '0', '0'],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(deviceProvider.notifier);

    notifier.markSceneActive(3);

    expect(container.read(deviceProvider).activeSceneIndex, 3);
    expect(prefs.getStringList('device_scene_saved'), [
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
      '0',
    ]);

    notifier.markSceneActive(99);

    expect(container.read(deviceProvider).activeSceneIndex, 3);
  });

  test(
    'manual controls clear active scene while status sync preserves it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(deviceProvider.notifier);

      notifier.markSceneActive(2);
      notifier.updateFromStatus(0, 10, 20, 30, 40);

      expect(container.read(deviceProvider).activeSceneIndex, 2);

      notifier.setBrightness(128);

      expect(container.read(deviceProvider).activeSceneIndex, isNull);

      notifier.markSceneActive(4);
      notifier.setColor(1, 2, 3);

      expect(container.read(deviceProvider).activeSceneIndex, isNull);

      notifier.markSceneActive(5);
      notifier.setMode(1);

      expect(container.read(deviceProvider).activeSceneIndex, isNull);
    },
  );
}
