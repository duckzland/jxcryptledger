import 'dart:async';

import 'runtime/runtime.dart';

class CoreEvent {
  CoreEvent._();

  static final StreamController<String> _controller = StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  static void emit(String action) {
    // Dont allow server to emit!
    bool isEmittable = !CoreRuntime.instance.isServer();
    if (isEmittable && !_controller.isClosed && _controller.hasListener) {
      _controller.add(action);
    }
  }
}
