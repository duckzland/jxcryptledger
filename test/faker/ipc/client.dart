import 'package:jxledger/ipc/client.dart';

import 'adapters.dart';

class IpcClientFaker extends IpcClient {
  int? lastOp;
  String? lastAction;
  dynamic lastKey;
  dynamic lastPayload;

  final Map<int, dynamic> _stubbedResponses = {};

  IpcClientFaker() : super(IpcAdaptersFaker());

  void stubResponse(int op, dynamic response) {
    _stubbedResponses[op] = response;
  }

  @override
  Future<dynamic> send({required int op, required String action, dynamic key, dynamic payload}) async {
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
