import 'dart:async';

class BleStatusQueryTracker {
  Completer<bool>? _pending;

  bool get isPending => _pending != null && !_pending!.isCompleted;

  Future<bool> begin() {
    fail();
    final completer = Completer<bool>();
    _pending = completer;
    return completer.future.whenComplete(() {
      if (identical(_pending, completer)) {
        _pending = null;
      }
    });
  }

  void succeed() => _complete(true);

  void fail() => _complete(false);

  void _complete(bool success) {
    final completer = _pending;
    if (completer != null && !completer.isCompleted) {
      completer.complete(success);
    }
  }
}
