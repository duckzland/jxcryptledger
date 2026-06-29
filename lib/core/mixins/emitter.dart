import 'dart:async';
import '../event.dart';

mixin CoreMixinsEmitter {
  StreamSubscription? _emitter;

  void emitterAction(String action) {}

  void emitterListen() {
    _emitter = CoreEvent.stream.listen((action) {
      emitterAction(action);
    });
  }

  void emitterEmit(String action) {
    CoreEvent.emit(action);
  }

  void emitterDispose() {
    _emitter?.cancel();
  }
}
