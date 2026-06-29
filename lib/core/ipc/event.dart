import 'dart:typed_data';

class CoreIpcBroadcastEvent {
  final int op;
  final String boxName;
  final String key;
  final Uint8List valueBytes;

  CoreIpcBroadcastEvent({required this.op, required this.boxName, required this.key, required this.valueBytes});

  bool isEqual(CoreIpcBroadcastEvent event) {
    if (op != event.op || boxName != event.boxName || key != event.key || valueBytes.lengthInBytes != event.valueBytes.lengthInBytes) {
      return false;
    }
    for (var i = 0; i < valueBytes.lengthInBytes; i++) {
      if (valueBytes[i] != event.valueBytes[i]) {
        return false;
      }
    }
    return true;
  }
}
