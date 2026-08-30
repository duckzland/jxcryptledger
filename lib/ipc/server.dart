import 'dart:io';
import 'dart:typed_data';

import 'abstracts/action.dart';
import 'status/op.dart';
import 'status/unlock.dart';

import 'protocol/buffer.dart';
import 'protocol/crypto.dart';
import 'protocol/packet.dart';

class IpcServer {
  final List<Socket> _slaves = [];
  final Uint8List sessionKey = IpcCrypto.createSessionKey(32);
  final IpcCrypto _crypto = IpcCrypto();

  ServerSocket? socket;
  IpcAction? handler;

  Future<IpcStatusUnlock> Function(Uint8List keyBytes)? unlocker;
  Future<void> Function()? shutdown;

  void Function()? disconnected;
  void Function(String message, [String group])? logger;

  bool Function({int exclude})? hasClient;

  bool _isDisposing = false;

  String pipeName = "";

  IpcServer();

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;

    for (var slave in List.from(_slaves)) {
      try {
        slave.destroy();
      } catch (_) {}
    }
    _slaves.clear();

    if (socket != null) {
      try {
        await socket!.close();
        socket = null;
      } catch (_) {}
    }

    handler?.dispose();
  }

  Future<void> start() async {
    await handler?.init();

    _crypto.setSessionKey(sessionKey);

    ServerSocket socket;
    try {
      socket = await ServerSocket.bind(InternetAddress(pipeName, type: InternetAddressType.unix), 0);
      logger?.call("Server running: $pipeName", "IPC");
    } catch (e) {
      logger?.call("Server failed to open: $pipeName with $e", "IPC");
      return;
    }

    socket.listen((client) {
      if (_isDisposing) return;

      _slaves.add(client);

      final IpcBuffer incomingBuffer = IpcBuffer();

      Future<void> disconnect([dynamic error]) async {
        if (error != null) {
          logger?.call("Connection disconnected with error: $error", "IPC");
        }

        _slaves.remove(client);
        try {
          client.destroy();
          disconnected?.call();
        } catch (_) {}
      }

      client.listen(
        (frame) async {
          if (_isDisposing) return;
          await processFrames(frame, incomingBuffer, client);
        },
        onDone: disconnect,
        onError: disconnect,
        cancelOnError: true,
      );
    });
  }

  Future<void> processFrames(Uint8List frame, IpcBuffer incomingBuffer, dynamic client) async {
    incomingBuffer.add(frame);

    IpcPacket? packet;
    while ((packet = incomingBuffer.parseNextAction()) != null) {
      if (_isDisposing) return;

      final currentPacket = packet!;
      final activeReqId = currentPacket.reqId;
      final actionCode = currentPacket.actionCode;
      final action = currentPacket.action;
      final rawKeyStr = currentPacket.key;
      Uint8List payload = currentPacket.payload;

      try {
        final dynamic nativeHiveKey = int.tryParse(rawKeyStr) ?? rawKeyStr;
        int sendOp = actionCode;
        final opName = IpcStatusOp.getName(actionCode);

        if (opName != "unlock" && opName != "shutdown") {
          if (payload.length < 28) {
            logger?.call(
              "SECURITY VIOLATION: Received unauthenticated packet for op: $actionCode from reqId: $activeReqId. Rejecting.",
              "IPC",
            );
            error(client, activeReqId);
            continue;
          }

          try {
            payload = await _crypto.decrypt(payload);
          } catch (e) {
            logger?.call("AUTHENTICATION FAILURE: Tampered or invalid signature block for op: $actionCode. Dropping.", "IPC");
            error(client, activeReqId);
            continue;
          }
        }

        Uint8List serializedResult = await _crypto.encrypt(await handler?.process(actionCode, action, rawKeyStr, payload) ?? Uint8List(0));

        switch (opName) {
          case "clear":
          case "delete":
          case "replace":
          case "multiPut":
          case "put":
            broadcast(actionCode, action, rawKeyStr, payload, exclude: client);
            break;

          case "unlock":
            try {
              final IpcStatusUnlock status = await unlocker?.call(payload) ?? IpcStatusUnlock.error;
              final builder = BytesBuilder();
              if (status.isUnlocked()) {
                builder.add([status.value]);
                builder.add(sessionKey);
                sendOp = IpcStatusOp.getCode("unlock");

                // Must broadcast so other instance mutate its screen to login screen!
                if (status.isFirstRun()) {
                  broadcast(actionCode, "database_created", '', Uint8List.fromList([status.value]), exclude: client);
                }
              } else {
                builder.add([status.value]);
                sendOp = IpcStatusOp.getCode("response");
              }
              serializedResult = builder.toBytes();
            } catch (e) {
              serializedResult = Uint8List.fromList([0]);
            }

            break;

          case "shutdown":
            if (hasClient != null && hasClient!.call(exclude: nativeHiveKey) == false) {
              await shutdown?.call();
              logger?.call("Shutdown request from $nativeHiveKey... shutting down.", "IPC");
            }
            break;

          default:
            break;
        }

        response(client, activeReqId, serializedResult, sendOp);
      } catch (e) {
        logger?.call("Failed to process action: $e", "IPC");
        error(client, activeReqId);
      }
    }
  }

  void response(Socket client, int reqId, dynamic result, int op) {
    if (_isDisposing) return;
    final responsePacket = IpcPacket(reqId: reqId, op: op, action: '', key: '', payload: result);
    try {
      client.add(responsePacket.toBytes());
    } catch (e) {
      logger?.call("Failed to send response to $client", "IPC");
      _slaves.remove(client);
      client.destroy();
      disconnected?.call();
    }
  }

  // @todo: Unify error with broadcast and pack the error object as payload with encryption, also mutate the client to accept it
  void error(Socket client, int activeReqId) {
    if (_isDisposing) return;
    final errorPacket = IpcPacket(reqId: activeReqId, op: IpcStatusOp.getCode("error"), action: '', key: '', payload: Uint8List(0));
    try {
      client.add(errorPacket.toBytes());
    } catch (e) {
      logger?.call("Failed to send error to $client", "IPC");
      _slaves.remove(client);
      client.destroy();
      disconnected?.call();
    }
  }

  void broadcast(int op, String action, String key, Uint8List payload, {Socket? exclude}) async {
    if (_isDisposing) return;

    Uint8List finalPayload = payload;
    final opName = IpcStatusOp.getName(op);
    try {
      switch (opName) {
        case "unlock":
        case "shutdown":
          break;

        default:
          finalPayload = await _crypto.encrypt(finalPayload);
          break;
      }
    } catch (e) {
      logger?.call("Failed to process payload: $e", "IPC");
      return;
    }

    final packet = IpcPacket(reqId: -1, op: op, action: action, key: key, payload: finalPayload);
    final Uint8List frame = packet.toBytes();

    for (var slave in _slaves) {
      if (slave != exclude) {
        try {
          slave.add(frame);
        } catch (e) {
          logger?.call("Failed to broadcast to $slave", "IPC");
          _slaves.remove(slave);
          slave.destroy();
          disconnected?.call();
        }
      }
    }
  }
}
