import 'dart:typed_data';

class CoreIpcBroadcastEvent {
  final int op;
  final String boxName;
  final String key;
  final Uint8List valueBytes;

  CoreIpcBroadcastEvent({required this.op, required this.boxName, required this.key, required this.valueBytes});
}
