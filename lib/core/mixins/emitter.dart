import 'dart:async';
import '../event.dart';

mixin CoreMixinsEmitter {
  StreamSubscription? _emitter;
  static final List<String> _pendingActions = [];
  static Timer? _debounceTimer;

  void emitterAction(String action) {}

  void emitterListen() {
    _emitter = CoreEvent.stream.listen((action) {
      if (!_pendingActions.contains(action)) {
        _pendingActions.add(action);
      }
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 32), _flushQueue);
    });
  }

  void _flushQueue() {
    for (final action in _pendingActions) {
      emitterAction(action);
    }
    _pendingActions.clear();
  }

  void emitterEmit(String action) {
    CoreEvent.emit(action);
  }

  void emitterDispose() {
    _emitter?.cancel();
  }
}
