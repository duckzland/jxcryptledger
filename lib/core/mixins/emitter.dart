import 'dart:async';

import '../event.dart';

mixin CoreMixinsEmitter {
  StreamSubscription? emitter;

  void emitterAction(String action) {}

  void emitterListen() {
    emitter = CoreEvent.stream.listen((action) {
      emitterAction(action);
    });
  }

  void emitterEmit(String action) {
    CoreEvent.emit(action);
  }

  void emitterDispose() {
    emitter?.cancel();
  }
}
