import 'package:jxledger/ipc/action.dart';
import 'package:jxledger/ipc/client.dart';

import 'adapters.dart';

class ClientFaker extends IpcClient {
  IpcAction? lastOp;
  String? lastAction;
  dynamic lastKey;
  dynamic lastPayload;

  final Map<IpcAction, dynamic> _stubbedResponses = {};

  ClientFaker() : super(AdaptersFaker());

  void stubResponse(IpcAction op, dynamic response) {
    _stubbedResponses[op] = response;
  }

  @override
  Future<dynamic> send({required IpcAction op, required String action, dynamic key, dynamic payload}) async {
    lastOp = op;
    lastAction = action;
    lastKey = key;
    lastPayload = payload;
    return _stubbedResponses[op];
  }

  // Override lifecycle methods to no‑op
  @override
  Future<void> start() async {}

  @override
  Future<void> reconnect() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> destroy() async {}
}
