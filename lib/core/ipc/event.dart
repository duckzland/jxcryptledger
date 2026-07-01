import 'dart:typed_data';

import 'action.dart';

class CoreIpcBroadcastEvent {
  final int op;
  final String action;
  final String key;
  final Uint8List payload;

  CoreIpcBroadcastEvent({required this.op, required this.action, required this.key, required this.payload});

  CoreIpcAction get actionCode => CoreIpcAction.fromCode(op);

  bool isEqual(CoreIpcBroadcastEvent event) {
    if (op != event.op || action != event.action || key != event.key || payload.lengthInBytes != event.payload.lengthInBytes) {
      return false;
    }
    for (var i = 0; i < payload.lengthInBytes; i++) {
      if (payload[i] != event.payload[i]) {
        return false;
      }
    }
    return true;
  }
}
