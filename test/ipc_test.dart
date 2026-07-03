import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jxledger/core/ipc/action.dart';
import 'package:jxledger/core/ipc/client.dart';
import 'package:jxledger/core/ipc/database/adapters.dart';
import 'package:jxledger/core/ipc/database/boxes.dart';
import 'package:jxledger/core/ipc/database/migration.dart';
import 'package:jxledger/core/ipc/event.dart';
import 'package:jxledger/core/ipc/protocol/buffer.dart';
import 'package:jxledger/core/ipc/protocol/converter.dart';
import 'package:jxledger/core/ipc/protocol/packet.dart';
import 'package:jxledger/core/ipc/server.dart';
import 'package:jxledger/core/mode.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:test/test.dart';

import 'database.dart';

String _testPipeName() {
  final suffix = DateTime.now().microsecondsSinceEpoch;
  if (Platform.isWindows) {
    return r'\\.\pipe\jxledger_test_pipe_' + suffix.toString();
  }
  return '/tmp/jxledger_test_pipe_$suffix.sock';
}

void main() {
  group('CoreIpcAction', () {
    test('returns known action for valid code', () {
      expect(CoreIpcAction.fromCode(0x02), CoreIpcAction.put);
      expect(CoreIpcAction.fromCode(0x03), CoreIpcAction.delete);
      expect(CoreIpcAction.fromCode(0xFF), CoreIpcAction.error);
    });

    test('returns unknown for invalid code', () {
      expect(CoreIpcAction.fromCode(0xAB), CoreIpcAction.unknown);
    });
  });

  group('CoreIpcPacket and CoreIpcBuffer', () {
    test('serializes and parses a single packet correctly', () {
      final payload = utf8.encode('hello world');
      final packet = CoreIpcPacket(
        reqId: 100,
        op: CoreIpcAction.put.code,
        action: 'transactions_box',
        key: '42',
        payload: Uint8List.fromList(payload),
      );

      final buffer = CoreIpcBuffer();
      buffer.add(packet.toBytes());

      final parsed = buffer.parseNextAction();
      expect(parsed, isNotNull);
      expect(parsed?.reqId, equals(100));
      expect(parsed?.op, equals(CoreIpcAction.put.code));
      expect(parsed?.action, equals('transactions_box'));
      expect(parsed?.key, equals('42'));
      expect(parsed?.payload, equals(Uint8List.fromList(payload)));
      expect(utf8.decode(parsed!.payload), equals('hello world'));
    });

    test('parses multiple packets from a single buffer', () {
      final packetA = CoreIpcPacket(reqId: 1, op: CoreIpcAction.clear.code, action: 'settings_box', key: '', payload: Uint8List(0));
      final packetB = CoreIpcPacket(reqId: 2, op: CoreIpcAction.extract.code, action: 'transactions_box', key: '', payload: Uint8List(0));

      final buffer = CoreIpcBuffer();
      buffer.add(packetA.toBytes());
      buffer.add(packetB.toBytes());

      final first = buffer.parseNextAction();
      final second = buffer.parseNextAction();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first?.reqId, equals(1));
      expect(second?.reqId, equals(2));
      expect(first?.action, equals('settings_box'));
      expect(second?.action, equals('transactions_box'));
    });

    test('does not parse incomplete packet until full data arrives', () {
      final packet = CoreIpcPacket(
        reqId: 7,
        op: CoreIpcAction.delete.code,
        action: 'watchers_box',
        key: 'abc',
        payload: Uint8List.fromList(utf8.encode('payload')),
      );
      final bytes = packet.toBytes();
      final buffer = CoreIpcBuffer();

      buffer.add(bytes.sublist(0, bytes.length - 3));
      expect(buffer.parseNextAction(), isNull);

      buffer.add(bytes.sublist(bytes.length - 3));
      final parsed = buffer.parseNextAction();
      expect(parsed?.reqId, equals(7));
      expect(parsed?.action, equals('watchers_box'));
      expect(parsed?.key, equals('abc'));
      expect(utf8.decode(parsed!.payload), equals('payload'));
    });
  });

  group('CoreIpcClient and CoreIpcServer', () {
    test('round-trips a request and receives a response', () async {
      final pipeName = _testPipeName();
      CoreMode.isServer = false;
      CoreMode.ipcPipeName = pipeName;

      final server = CoreIpcServer();
      final client = CoreIpcClient(CoreIpcAdapters());
      final keyBytes = Uint8List.fromList([1, 2, 3]);

      client.pipeName = pipeName;
      server.pipeName = pipeName;
      server.database = DatabaseFaker(CoreIpcBoxes(), CoreIpcAdapters(), CoreIpcMigration());

      server.unlocker = (Uint8List bytes) async {
        expect(bytes, equals(keyBytes));
        return true;
      };

      // await server.database.init();
      await server.start();
      await Future.delayed(const Duration(milliseconds: 150));
      await client.start();
      await Future.delayed(const Duration(milliseconds: 150));

      addTearDown(() async {
        await client.dispose();
        await server.dispose();
      });

      final response = await client.send(op: CoreIpcAction.unlock, action: 'auth', key: 'unlock', payload: keyBytes);

      expect(response, isA<Uint8List>());
      expect(response.length, equals(32));
    });

    // Not working yet!
    // test('broadcasts events to connected clients', () async {
    //   final pipeName = _testPipeName();
    //   CoreMode.isServer = false;
    //   CoreMode.ipcPipeName = pipeName;

    //   final server = CoreIpcServer();
    //   final client = CoreIpcClient(CoreIpcAdapters());
    //   final client2 = CoreIpcClient(CoreIpcAdapters());
    //   final completer = Completer<CoreIpcBroadcastEvent>();

    //   client.pipeName = pipeName;

    //   client2.pipeName = pipeName;
    //   server.pipeName = pipeName;
    //   server.database = DatabaseFaker(CoreIpcBoxes(), CoreIpcAdapters(), CoreIpcMigration());

    //   final subscription = client2.onBroadcast.listen((event) {
    //     print("this debug $event");
    //     // if (!completer.isCompleted) {
    //     // completer.complete(event);
    //     //}

    //     //      // Wait for the event
    //     // final event = await completer.future.timeout(const Duration(seconds: 20));

    //     // Assertions
    //     expect(event.action, equals('transactions_box1'));
    //     expect(event.key, equals('42'));
    //     // expect(event.payload, equals(payload));
    //   });

    //   await server.start();
    //   await Future.delayed(const Duration(milliseconds: 150));
    //   await client.start();
    //   await client2.start();
    //   await Future.delayed(const Duration(milliseconds: 150));

    //   addTearDown(() async {
    //     await subscription.cancel();
    //     await client.dispose();
    //     await client2.dispose();
    //     await server.dispose();
    //   });

    //   final keyBytes = Uint8List.fromList([1, 2, 3]);
    //   server.unlocker = (bytes) async => true;

    //   final sessionKey = server.sessionKey;

    //   final handshakeBytes = await client.send(op: CoreIpcAction.unlock, action: 'auth', key: 'unlock', payload: keyBytes);
    //   expect(handshakeBytes, equals(sessionKey));

    //   final handshakeBytes2 = await client2.send(op: CoreIpcAction.unlock, action: 'auth', key: 'unlock', payload: keyBytes);
    //   expect(handshakeBytes, equals(sessionKey));

    //   print(handshakeBytes2);

    //   // client.sessionKey = handshakeBytes;

    //   // Need to modify this to check agains TransactionModel as the put will return TransactionModel as dynamic object
    //   await Future.delayed(const Duration(milliseconds: 150));

    //   final testCrypto = CoreIpcCrypto(key: server.sessionKey);
    //   final rawPayload = Uint8List.fromList([1, 2, 3]);
    //   final encryptedPayload = await testCrypto.encrypt(rawPayload);

    //   server.broadcast(CoreIpcAction.put, 'transactions_box', '42', encryptedPayload);

    //   // final event = await completer.future.timeout(const Duration(seconds: 20));
    //   expect(event.action, equals('transactions_box'));
    //   expect(event.key, equals('42'));
    //   expect(event.payload, equals(Uint8List.fromList([1, 2, 3])));

    //   // Build a real TransactionModel
    //   final transaction = TransactionsModel(
    //     tid: '42',
    //     pid: '0',
    //     rid: '0',
    //     srId: 123,
    //     rrId: 231,
    //     srAmount: 1.0,
    //     rrAmount: 2.0,
    //     balance: 3.0,
    //     status: 0,
    //     closable: true,
    //     timestamp: DateTime.now().millisecondsSinceEpoch,
    //     meta: {},
    //   );
    //   final converter = CoreIpcConverter(CoreIpcAdapters());
    //   final payload = converter.toBytes(CoreIpcAction.put, 'transactions_box', transaction);

    //   // Broadcast the model directly
    //   client.send(op: CoreIpcAction.put, action: 'transactions_box', key: '42', payload: transaction);
    //   server.broadcast(CoreIpcAction.put, 'transactions_box', transaction.uuid, payload!);

    //   // // Wait for the event
    //   final event = await completer.future.timeout(const Duration(seconds: 20));

    //   // // Assertions
    //   expect(event.action, equals('transactions_box'));
    //   expect(event.key, equals('42'));
    //   expect(event.payload, equals(payload));

    //   final data = event.payload as TransactionsModel;
    //   expect(data.uuid, equals('42'));
    //   expect(data.balance, equals(3.0));
    //   expect(data, isA<TransactionsModel>());
    // });
  });
}
