import 'package:jxledger/core/ipc/action.dart';
import 'package:jxledger/core/ipc/client.dart';

import 'adapters.dart';

class ClientFaker extends CoreIpcClient {
  CoreIpcAction? lastOp;
  String? lastAction;
  dynamic lastKey;
  dynamic lastPayload;

  final Map<CoreIpcAction, dynamic> _stubbedResponses = {};

  ClientFaker() : super(AdaptersFaker());

  void stubResponse(CoreIpcAction op, dynamic response) {
    _stubbedResponses[op] = response;
  }

  @override
  Future<dynamic> send({required CoreIpcAction op, required String action, dynamic key, dynamic payload}) async {
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
