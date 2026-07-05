import 'action.dart';

class IpcBroadcastEvent {
  final int op;
  final String action;
  final String key;
  final dynamic payload;

  IpcBroadcastEvent({required this.op, required this.action, required this.key, required this.payload});

  IpcAction get actionCode => IpcAction.fromCode(op);
}
