import 'dart:async';

import 'runtime/runtime.dart';

class CoreEvent {
  CoreEvent._();

  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static final Set<String> _pendingActions = {};
  static Timer? _throttleTimer;

  static Stream<String> get stream => _controller.stream;

  static void emit(String action) {
    bool isEmittable = !CoreRuntime.instance.isServer();
    if (!isEmittable || _controller.isClosed) return;

    _pendingActions.add(action);

    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 32), _flushThrottledEvents);
  }

  static void _flushThrottledEvents() {
    if (_controller.isClosed || !_controller.hasListener) {
      _pendingActions.clear();
      return;
    }

    for (final action in _pendingActions) {
      _controller.add(action);
    }

    _pendingActions.clear();
  }
}
