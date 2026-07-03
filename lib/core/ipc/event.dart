import 'action.dart';

class CoreIpcBroadcastEvent {
  final int op;
  final String action;
  final String key;
  final dynamic payload;

  CoreIpcBroadcastEvent({required this.op, required this.action, required this.key, required this.payload});

  CoreIpcAction get actionCode => CoreIpcAction.fromCode(op);
}
