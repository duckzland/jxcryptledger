import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:jxledger/core/ipc/action.dart';
import 'package:jxledger/core/ipc/client.dart';
import 'package:jxledger/core/ipc/event.dart';
import 'package:jxledger/core/ipc/protocol/buffer.dart';
import 'package:jxledger/core/ipc/protocol/packet.dart';
import 'package:jxledger/core/ipc/server.dart';
import 'package:jxledger/core/mode.dart';
import 'package:test/test.dart';

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

  group('CoreIpcBroadcastEvent', () {
    test('isEqual returns true for matching events', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final eventA = CoreIpcBroadcastEvent(op: 0x02, action: 'box', key: 'x', payload: payload);
      final eventB = CoreIpcBroadcastEvent(op: 0x02, action: 'box', key: 'x', payload: Uint8List.fromList([1, 2, 3]));
      expect(eventA.isEqual(eventB), isTrue);
      expect(eventA.actionCode, CoreIpcAction.put);
    });

    test('isEqual returns false when payload differs', () {
      final eventA = CoreIpcBroadcastEvent(op: 0x02, action: 'box', key: 'x', payload: Uint8List.fromList([1, 2, 3]));
      final eventB = CoreIpcBroadcastEvent(op: 0x02, action: 'box', key: 'x', payload: Uint8List.fromList([1, 2, 4]));
      expect(eventA.isEqual(eventB), isFalse);
    });

    test('isEqual returns false for different meta', () {
      final payload = Uint8List.fromList([1, 2, 3]);
      final eventA = CoreIpcBroadcastEvent(op: 0x02, action: 'box', key: 'x', payload: payload);
      final eventB = CoreIpcBroadcastEvent(op: 0x03, action: 'box', key: 'x', payload: payload);
      expect(eventA.isEqual(eventB), isFalse);
    });
  });

  group('CoreIpcClient and CoreIpcServer', () {
    test('round-trips a request and receives a response', () async {
      final pipeName = _testPipeName();
      CoreMode.isServer = false;
      CoreMode.ipcPipeName = pipeName;

      final server = CoreIpcServer('test-server');
      final client = CoreIpcClient();
      final keyBytes = Uint8List.fromList([1, 2, 3]);

      server.unlocker = (Uint8List bytes) async {
        expect(bytes, equals(keyBytes));
        return true;
      };

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
      expect(response, Uint8List.fromList([1]));
    });

    test('broadcasts events to connected clients', () async {
      final pipeName = _testPipeName();
      CoreMode.isServer = false;
      CoreMode.ipcPipeName = pipeName;

      final server = CoreIpcServer('test-broadcast');
      final client = CoreIpcClient();
      final completer = Completer<CoreIpcBroadcastEvent>();
      final subscription = client.onBroadcast.listen((event) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      });

      await server.start();
      await Future.delayed(const Duration(milliseconds: 150));
      await client.start();
      await Future.delayed(const Duration(milliseconds: 150));

      addTearDown(() async {
        await subscription.cancel();
        await client.dispose();
        await server.dispose();
      });

      server.broadcast(CoreIpcAction.put, 'transactions_box', '42', Uint8List.fromList([1, 2, 3]));

      final event = await completer.future.timeout(const Duration(seconds: 2));
      expect(event.action, equals('transactions_box'));
      expect(event.key, equals('42'));
      expect(event.payload, equals(Uint8List.fromList([1, 2, 3])));
    });
  });
}
