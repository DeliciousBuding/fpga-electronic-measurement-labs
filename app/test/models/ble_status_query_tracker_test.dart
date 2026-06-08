import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_ble_controller/models/ble_status_query_tracker.dart';

void main() {
  test('status query tracker completes pending query as success', () async {
    final tracker = BleStatusQueryTracker();

    final query = tracker.begin();
    expect(tracker.isPending, isTrue);

    tracker.succeed();

    await expectLater(query, completion(isTrue));
    expect(tracker.isPending, isFalse);
  });

  test('status query tracker completes pending query as failure', () async {
    final tracker = BleStatusQueryTracker();

    final query = tracker.begin();
    tracker.fail();

    await expectLater(query, completion(isFalse));
    expect(tracker.isPending, isFalse);
  });

  test('starting a new query fails the previous pending query', () async {
    final tracker = BleStatusQueryTracker();

    final first = tracker.begin();
    final second = tracker.begin();
    tracker.succeed();

    await expectLater(first, completion(isFalse));
    await expectLater(second, completion(isTrue));
    expect(tracker.isPending, isFalse);
  });

  test('success and failure are idempotent after completion', () async {
    final tracker = BleStatusQueryTracker();

    final query = tracker.begin();
    tracker.succeed();
    tracker.fail();
    tracker.succeed();

    await expectLater(query, completion(isTrue));
    expect(tracker.isPending, isFalse);
  });
}
