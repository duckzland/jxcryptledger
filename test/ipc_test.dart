import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:jxledger/core/ipc/action.dart';
import 'package:jxledger/core/ipc/box.dart';
import 'package:jxledger/core/ipc/client.dart';
import 'package:jxledger/core/ipc/database/adapters.dart';
import 'package:jxledger/core/ipc/database/boxes.dart';
import 'package:jxledger/core/ipc/database/migration.dart';
import 'package:jxledger/core/ipc/event.dart';
import 'package:jxledger/core/ipc/protocol/buffer.dart';
import 'package:jxledger/core/ipc/protocol/converter.dart';
import 'package:jxledger/core/ipc/protocol/crypto.dart';
import 'package:jxledger/core/ipc/protocol/packet.dart';
import 'package:jxledger/core/ipc/protocol/reader.dart';
import 'package:jxledger/core/ipc/protocol/writer.dart';
import 'package:jxledger/core/ipc/server.dart';
import 'package:jxledger/core/mode.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/system/unlock/status.dart';
import 'package:test/test.dart';

import 'faker/adapters.dart';
import 'faker/client.dart';
import 'faker/database.dart';

Future<String> _testPipeName() async {
  WidgetsFlutterBinding.ensureInitialized();
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final dir = Directory.current;
  final path = '${dir.path}/test/tmp';

  final newDir = Directory(path);
  if (!await newDir.exists()) {
    await newDir.create(recursive: true);
  }

  return '$path/jxledger-$suffix.sock';
}

TransactionsModel makeTx(String tid, {double balance = 0.0}) {
  return TransactionsModel(
    tid: tid,
    pid: 'p-$tid',
    rid: 'r-$tid',
    srId: 111,
    rrId: 222,
    srAmount: 1.0,
    rrAmount: 2.0,
    balance: balance,
    status: 0,
    closable: true,
    timestamp: DateTime.now().millisecondsSinceEpoch,
    meta: {},
  );
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

  group('CoreIpcPacket', () {
    test('serializes and deserializes correctly', () {
      final payload = utf8.encode('hello world');
      final packet = CoreIpcPacket(
        reqId: 123,
        op: CoreIpcAction.put.code,
        action: 'transactions_box',
        key: '42',
        payload: Uint8List.fromList(payload),
      );

      final bytes = packet.toBytes();
      final parsed = CoreIpcPacket.fromBytes(bytes);

      expect(parsed.reqId, equals(123));
      expect(parsed.op, equals(CoreIpcAction.put.code));
      expect(parsed.action, equals('transactions_box'));
      expect(parsed.key, equals('42'));
      expect(utf8.decode(parsed.payload), equals('hello world'));
    });

    test('handles empty payload', () {
      final packet = CoreIpcPacket(reqId: 1, op: CoreIpcAction.clear.code, action: 'settings_box', key: '', payload: Uint8List(0));

      final bytes = packet.toBytes();
      final parsed = CoreIpcPacket.fromBytes(bytes);

      expect(parsed.reqId, equals(1));
      expect(parsed.op, equals(CoreIpcAction.clear.code));
      expect(parsed.action, equals('settings_box'));
      expect(parsed.key, equals(''));
      expect(parsed.payload.length, equals(0));
    });

    test('handles non-ASCII characters in action and key', () {
      final packet = CoreIpcPacket(
        reqId: 2,
        op: CoreIpcAction.put.code,
        action: '测试箱', // Chinese characters
        key: 'ключ', // Cyrillic characters
        payload: Uint8List.fromList(utf8.encode('payload')),
      );

      final bytes = packet.toBytes();
      final parsed = CoreIpcPacket.fromBytes(bytes);

      expect(parsed.reqId, equals(2));
      expect(parsed.action, equals('测试箱'));
      expect(parsed.key, equals('ключ'));
      expect(utf8.decode(parsed.payload), equals('payload'));
    });

    test('actionCode returns correct CoreIpcAction', () {
      final packet = CoreIpcPacket(reqId: 3, op: CoreIpcAction.delete.code, action: 'box', key: 'k', payload: Uint8List(0));

      expect(packet.actionCode, equals(CoreIpcAction.delete));
    });
  });

  group('CoreIpcBuffer', () {
    test('parses a complete packet correctly', () {
      final payload = utf8.encode('hello');
      final packet = CoreIpcPacket(
        reqId: 1,
        op: CoreIpcAction.put.code,
        action: 'test_box',
        key: 'abc',
        payload: Uint8List.fromList(payload),
      );

      final buffer = CoreIpcBuffer();
      buffer.add(packet.toBytes());

      final parsed = buffer.parseNextAction();
      expect(parsed, isNotNull);
      expect(parsed?.reqId, equals(1));
      expect(parsed?.op, equals(CoreIpcAction.put.code));
      expect(parsed?.action, equals('test_box'));
      expect(parsed?.key, equals('abc'));
      expect(utf8.decode(parsed!.payload), equals('hello'));
    });

    test('returns null until full packet arrives', () {
      final payload = utf8.encode('data');
      final packet = CoreIpcPacket(
        reqId: 2,
        op: CoreIpcAction.delete.code,
        action: 'box',
        key: 'key',
        payload: Uint8List.fromList(payload),
      );

      final bytes = packet.toBytes();
      final buffer = CoreIpcBuffer();

      buffer.add(bytes.sublist(0, bytes.length - 2));
      expect(buffer.parseNextAction(), isNull);

      buffer.add(bytes.sublist(bytes.length - 2));
      final parsed = buffer.parseNextAction();
      expect(parsed, isNotNull);
      expect(parsed?.reqId, equals(2));
      expect(parsed?.action, equals('box'));
      expect(parsed?.key, equals('key'));
      expect(utf8.decode(parsed!.payload), equals('data'));
    });

    test('parses multiple packets sequentially', () {
      final packetA = CoreIpcPacket(reqId: 10, op: CoreIpcAction.clear.code, action: 'settings_box', key: '', payload: Uint8List(0));
      final packetB = CoreIpcPacket(reqId: 11, op: CoreIpcAction.extract.code, action: 'transactions_box', key: '', payload: Uint8List(0));

      final buffer = CoreIpcBuffer();
      buffer.add(packetA.toBytes());
      buffer.add(packetB.toBytes());

      final first = buffer.parseNextAction();
      final second = buffer.parseNextAction();

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first?.reqId, equals(10));
      expect(second?.reqId, equals(11));
      expect(first?.action, equals('settings_box'));
      expect(second?.action, equals('transactions_box'));
    });

    test('clears buffer correctly', () {
      final packet = CoreIpcPacket(
        reqId: 99,
        op: CoreIpcAction.put.code,
        action: 'clear_test',
        key: 'k',
        payload: Uint8List.fromList(utf8.encode('x')),
      );

      final buffer = CoreIpcBuffer();
      buffer.add(packet.toBytes());
      expect(buffer.length, greaterThan(0));

      buffer.clear();
      expect(buffer.length, equals(0));
      expect(buffer.parseNextAction(), isNull);
    });
  });

  group('CoreIpcConverter', () {
    final converter = CoreIpcConverter(AdaptersFaker());

    late TransactionsModel txA;
    late TransactionsModel txB;
    late TransactionsModel txC;
    late TransactionsModel txD;

    setUp(() {
      txA = makeTx("123", balance: 3.0);
      txB = makeTx("a", balance: 10.0);
      txC = makeTx("b", balance: 20.0);
      txD = makeTx("99", balance: 5.0);
    });

    test('toBytes with put serializes TransactionsModel using adapter', () {
      final bytes = converter.toBytes(CoreIpcAction.put, 'transactions_box', txA);
      expect(bytes, isNotNull);

      final decoded = converter.fromBytes(CoreIpcAction.put, 'transactions_box', bytes);
      expect(decoded, isA<TransactionsModel>());
      expect((decoded as TransactionsModel).tid, equals('123'));
      expect(decoded.balance, equals(3.0));
    });

    test('toBytes with multiPut serializes multiple TransactionsModel payloads', () {
      final payloads = [txB, txC];
      final bytes = converter.toBytes(CoreIpcAction.multiPut, 'transactions_box', payloads);
      expect(bytes, isNotNull);

      final decoded = converter.fromBytes(CoreIpcAction.multiPut, 'transactions_box', bytes);
      expect(decoded, isA<List>());
      expect(decoded.length, equals(2));

      final decodedTx1 = decoded[0] as TransactionsModel;
      final decodedTx2 = decoded[1] as TransactionsModel;

      expect(decodedTx1.tid, equals('a'));
      expect(decodedTx1.balance, equals(10.0));
      expect(decodedTx2.tid, equals('b'));
      expect(decodedTx2.balance, equals(20.0));
    });

    test('toBytes with unlock returns raw payload', () {
      final raw = Uint8List.fromList([1, 2, 3]);
      final bytes = converter.toBytes(CoreIpcAction.unlock, 'auth', raw);
      expect(bytes, equals(raw));
    });

    test('toBytes with notification encodes string to UTF8', () {
      final msg = 'notify';
      final bytes = converter.toBytes(CoreIpcAction.notification, 'note', msg);
      expect(utf8.decode(bytes!), equals(msg));
    });

    test('fromSenderBytes with extract decodes list of items', () {
      final payloads = [txA];
      final bytes = converter.toBytes(CoreIpcAction.multiPut, 'transactions_box', payloads);
      final decoded = converter.fromBytes(CoreIpcAction.extract, 'transactions_box', bytes);

      expect(decoded, isA<List>());
      expect(decoded.length, equals(1));
      final decodedTx = decoded.first as TransactionsModel;
      expect(decodedTx.tid, equals('123'));
      expect(decodedTx.balance, equals(3.0));
    });

    test('fromSenderBytes with clear returns int32 or 0 for empty', () {
      final empty = Uint8List(0);
      expect(converter.fromBytes(CoreIpcAction.clear, 'box', empty), equals(0));

      final bd = ByteData(4)..setInt32(0, 42, Endian.big);
      final bytes = bd.buffer.asUint8List();
      expect(converter.fromBytes(CoreIpcAction.clear, 'box', bytes), equals(42));
    });

    test('fromSenderBytes with unlock returns decoded tx or null', () {
      final txBytes = converter.toBytes(CoreIpcAction.put, 'transactions_box', txD)!;
      final good = Uint8List.fromList([1, ...txBytes]);
      final bad = Uint8List.fromList([0, ...txBytes]);

      final decodedGood = converter.fromBytes(CoreIpcAction.unlock, 'transactions_box', good);
      expect(decodedGood, isNotNull);

      final txDecoded = converter.fromBytes(CoreIpcAction.put, 'transactions_box', decodedGood);
      expect(txDecoded, isA<TransactionsModel>());
      expect((txDecoded as TransactionsModel).tid, equals('99'));
      expect(txDecoded.balance, equals(5.0));

      final decodedBad = converter.fromBytes(CoreIpcAction.unlock, 'transactions_box', bad);
      expect(decodedBad, isNull);
    });

    test('fromBytes with put decodes single TransactionsModel', () {
      final bytes = converter.toBytes(CoreIpcAction.put, 'transactions_box', txA);
      final decoded = converter.fromBytes(CoreIpcAction.put, 'transactions_box', bytes);

      expect(decoded, isA<TransactionsModel>());
      expect((decoded as TransactionsModel).tid, equals('123'));
      expect(decoded.balance, equals(3.0));
    });

    test('fromBytes with multiPut decodes multiple TransactionsModel items', () {
      final payloads = [txB, txC];
      final bytes = converter.toBytes(CoreIpcAction.multiPut, 'transactions_box', payloads);
      final decoded = converter.fromBytes(CoreIpcAction.multiPut, 'transactions_box', bytes);

      expect(decoded, isA<List>());
      expect(decoded.length, equals(2));

      final decodedTx1 = decoded[0] as TransactionsModel;
      final decodedTx2 = decoded[1] as TransactionsModel;

      expect(decodedTx1.tid, equals('a'));
      expect(decodedTx1.balance, equals(10.0));
      expect(decodedTx2.tid, equals('b'));
      expect(decodedTx2.balance, equals(20.0));
    });
  });

  group('CoreIpcCrypto', () {
    test('createSessionKey generates UTF8 bytes of correct length', () {
      final keyBytes = CoreIpcCrypto.createSessionKey(16);
      final keyString = utf8.decode(keyBytes);
      expect(keyString.length, equals(16));
      expect(keyString, matches(RegExp(r'^[a-zA-Z0-9]+$')));
    });

    test('setSessionKey accepts String and Uint8List', () {
      final crypto = CoreIpcCrypto();
      crypto.setSessionKey('abcd1234');
      expect(crypto.hasActiveKey, isTrue);

      final raw = Uint8List.fromList(utf8.encode('abcd1234'));
      crypto.setSessionKey(raw);
      expect(crypto.hasActiveKey, isTrue);
    });

    test('clearSessionKey resets active key state', () {
      final crypto = CoreIpcCrypto(key: 'abcd1234');
      expect(crypto.hasActiveKey, isTrue);
      crypto.clearSessionKey();
      expect(crypto.hasActiveKey, isFalse);
    });

    test('encrypt and decrypt roundtrip works', () async {
      // 32‑byte key string
      final keyString = '0123456789abcdef0123456789abcdef';
      final crypto = CoreIpcCrypto(key: keyString);

      final plain = Uint8List.fromList(utf8.encode('hello world'));

      final encrypted = await crypto.encrypt(plain);
      expect(encrypted, isNotNull);
      expect(encrypted, isNotEmpty);

      final decrypted = await crypto.decrypt(encrypted);
      expect(utf8.decode(decrypted), equals('hello world'));
    });

    test('encrypt throws if no active key', () async {
      final crypto = CoreIpcCrypto();
      final plain = Uint8List.fromList([1, 2, 3]);
      expect(() => crypto.encrypt(plain), throwsStateError);
    });

    test('decrypt throws if no active key', () async {
      final crypto = CoreIpcCrypto();
      final encrypted = Uint8List.fromList([1, 2, 3]);
      expect(() => crypto.decrypt(encrypted), throwsStateError);
    });

    test('decrypt throws ArgumentError on tampered data', () async {
      // 32‑byte key string
      final keyString = '0123456789abcdef0123456789abcdef';
      final crypto = CoreIpcCrypto(key: keyString);

      final plain = Uint8List.fromList(utf8.encode('secure data'));
      final encrypted = await crypto.encrypt(plain);

      // Tamper with encrypted bytes (flip last byte)
      encrypted[encrypted.length - 1] ^= 0xFF;

      expect(() async => await crypto.decrypt(encrypted), throwsArgumentError);
    });
  });

  group('CoreIpcReader', () {
    test('readByte and skip advance offset correctly', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final reader = CoreIpcReader(bytes);

      expect(reader.readByte(), equals(1));
      expect(reader.usedBytes, equals(1));

      reader.skip(1);
      expect(reader.readByte(), equals(3));
      expect(reader.availableBytes, equals(0));
    });

    test('readWord, readInt32, readUint32, readInt, readDouble', () {
      final bd = ByteData(26);
      bd.setUint16(0, 0x1234, Endian.big);
      bd.setInt32(2, -42, Endian.big);
      bd.setUint32(6, 0xDEADBEEF, Endian.big);
      bd.setInt64(10, 123456789, Endian.big);
      bd.setFloat64(18, 3.14159, Endian.big);

      final reader = CoreIpcReader(bd.buffer.asUint8List());
      expect(reader.readWord(), equals(0x1234));
      expect(reader.readInt32(), equals(-42));
      expect(reader.readUint32(), equals(0xDEADBEEF));
      expect(reader.readInt(), equals(123456789));
      expect(reader.readDouble(), closeTo(3.14159, 1e-6));
    });

    test('readBool, readString, readByteList', () {
      final str = 'hi';
      final strBytes = utf8.encode(str);
      final bd = ByteData(1 + 8 + strBytes.length);
      bd.setUint8(0, 1); // bool true
      bd.setInt64(1, strBytes.length, Endian.big);
      bd.buffer.asUint8List().setRange(9, 9 + strBytes.length, strBytes);

      final reader = CoreIpcReader(bd.buffer.asUint8List());
      expect(reader.readBool(), isTrue);
      expect(reader.readString(), equals('hi'));
    });

    test('readIntList, readDoubleList, readBoolList', () {
      final bd = ByteData(8 + 8 + 8 + 8 + 8 + 8 + 8 + 8 + 8);
      var offset = 0;
      bd.setInt64(offset, 2, Endian.big);
      offset += 8;
      bd.setInt64(offset, 42, Endian.big);
      offset += 8;
      bd.setInt64(offset, 43, Endian.big);
      offset += 8;
      bd.setInt64(offset, 2, Endian.big);
      offset += 8;
      bd.setFloat64(offset, 1.5, Endian.big);
      offset += 8;
      bd.setFloat64(offset, 2.5, Endian.big);
      offset += 8;
      bd.setInt64(offset, 2, Endian.big);
      offset += 8;
      bd.setUint8(offset, 1);
      offset += 1;
      bd.setUint8(offset, 0);

      final reader = CoreIpcReader(bd.buffer.asUint8List());
      expect(reader.readIntList(), equals([42, 43]));
      expect(reader.readDoubleList(), equals([1.5, 2.5]));
      expect(reader.readBoolList(), equals([true, false]));
    });

    test('readStringList and readMap', () {
      final str1 = utf8.encode('foo');
      final str2 = utf8.encode('bar');
      final bb = BytesBuilder();

      // length = 2
      final lenBytes = ByteData(8)..setInt64(0, 2, Endian.big);
      bb.add(lenBytes.buffer.asUint8List());

      // first string
      final s1Len = ByteData(8)..setInt64(0, str1.length, Endian.big);
      bb.add(s1Len.buffer.asUint8List());
      bb.add(str1);

      // second string
      final s2Len = ByteData(8)..setInt64(0, str2.length, Endian.big);
      bb.add(s2Len.buffer.asUint8List());
      bb.add(str2);

      final reader = CoreIpcReader(bb.toBytes());
      expect(reader.readStringList(), equals(['foo', 'bar']));
    });

    test('read dynamic types by typeId', () {
      final bb = BytesBuilder();

      // bool true
      bb.add([1]); // typeId
      bb.add([1]); // value

      // int 99
      bb.add([2]); // typeId
      final intBytes = ByteData(8)..setInt64(0, 99, Endian.big);
      bb.add(intBytes.buffer.asUint8List());

      // double 2.5
      bb.add([3]); // typeId
      final dblBytes = ByteData(8)..setFloat64(0, 2.5, Endian.big);
      bb.add(dblBytes.buffer.asUint8List());

      // string "baz"
      bb.add([4]); // typeId
      final str = utf8.encode('baz');
      final strLen = ByteData(8)..setInt64(0, str.length, Endian.big);
      bb.add(strLen.buffer.asUint8List());
      bb.add(str);

      final reader = CoreIpcReader(bb.toBytes());
      expect(reader.read(), isTrue);
      expect(reader.read(), equals(99));
      expect(reader.read(), closeTo(2.5, 1e-6));
      expect(reader.read(), equals('baz'));
    });
  });

  group('CoreIpcWriter', () {
    test('writeByte, writeWord, writeInt32, writeUint32, writeInt, writeDouble', () {
      final writer = CoreIpcWriter();
      writer.writeByte(0x12);
      writer.writeWord(0x3456);
      writer.writeInt32(-42);
      writer.writeUint32(0xDEADBEEF);
      writer.writeInt(123456789);
      writer.writeDouble(3.14159);

      final bytes = writer.toBytes();
      final reader = CoreIpcReader(bytes);

      expect(reader.readByte(), equals(0x12));
      expect(reader.readWord(), equals(0x3456));
      expect(reader.readInt32(), equals(-42));
      expect(reader.readUint32(), equals(0xDEADBEEF));
      expect(reader.readInt(), equals(123456789));
      expect(reader.readDouble(), closeTo(3.14159, 1e-6));
    });

    test('writeBool and writeString', () {
      final writer = CoreIpcWriter();
      writer.writeBool(true);
      writer.writeString('hello');

      final bytes = writer.toBytes();
      final reader = CoreIpcReader(bytes);

      expect(reader.readBool(), isTrue);
      expect(reader.readString(), equals('hello'));
    });

    test('writeByteList, writeIntList, writeDoubleList, writeBoolList', () {
      final writer = CoreIpcWriter();
      writer.writeByteList([1, 2, 3]);
      writer.writeIntList([42, 43]);
      writer.writeDoubleList([1.5, 2.5]);
      writer.writeBoolList([true, false]);

      final bytes = writer.toBytes();
      final reader = CoreIpcReader(bytes);

      expect(reader.readByteList(), equals([1, 2, 3]));
      expect(reader.readIntList(), equals([42, 43]));
      expect(reader.readDoubleList(), equals([1.5, 2.5]));
      expect(reader.readBoolList(), equals([true, false]));
    });

    test('writeStringList and writeMap', () {
      final writer = CoreIpcWriter();
      writer.writeStringList(['foo', 'bar']);
      writer.writeMap({'x': 1, 'y': 2});

      final bytes = writer.toBytes();
      final reader = CoreIpcReader(bytes);

      expect(reader.readStringList(), equals(['foo', 'bar']));
      expect(reader.readMap(), equals({'x': 1, 'y': 2}));
    });

    test('write dynamic types with typeId', () {
      final writer = CoreIpcWriter();
      writer.write(true);
      writer.write(99);
      writer.write(2.5);
      writer.write('baz');
      writer.write(Uint8List.fromList([7, 8]));
      writer.write([1, 2]);
      writer.write({'a': 10});
      writer.write(MapEntry('k', 'v'));

      final bytes = writer.toBytes();
      final reader = CoreIpcReader(bytes);

      expect(reader.read(), isTrue);
      expect(reader.read(), equals(99));
      expect(reader.read(), closeTo(2.5, 1e-6));
      expect(reader.read(), equals('baz'));
      expect(reader.read(), equals(Uint8List.fromList([7, 8])));
      expect(reader.read(), equals([1, 2]));
      expect(reader.read(), equals({'a': 10}));
      final entry = reader.read() as MapEntry;
      expect(entry.key, equals('k'));
      expect(entry.value, equals('v'));
    });
  });

  group('CoreIpcBox', () {
    late CoreIpcBox<TransactionsModel> box;
    late ClientFaker client;
    late CoreIpcAdapters adapters;

    setUp(() {
      client = ClientFaker();
      adapters = CoreIpcAdapters(); // stub or real adapters
      box = CoreIpcBox<TransactionsModel>('transactions_box', adapters, client);
    });

    test('init populates items from client', () async {
      client.stubResponse(CoreIpcAction.extract, [makeTx('id1', balance: 10.0), makeTx('id2', balance: 20.0)]);

      await box.init();
      expect(box.length, equals(2));
      expect(box.get('id1')?.tid, equals('id1'));
      expect(box.get('id2')?.balance, equals(20.0));
    });

    test('put sends to client and stores item', () async {
      final tx = makeTx('idX', balance: 99.0);
      await box.put(tx.tid, tx);

      expect(client.lastOp, equals(CoreIpcAction.put));
      expect(box.get('idX')?.balance, equals(99.0));
    });

    test('clear empties items and returns count', () async {
      client.stubResponse(CoreIpcAction.clear, 5);
      box.items['id'] = makeTx('id', balance: 5.0);

      final count = await box.clear();
      expect(count, equals(5));
      expect(box.isEmpty, isTrue);
    });

    test('delete removes item and sends to client', () async {
      final tx = makeTx('idY', balance: 7.0);
      box.items[tx.tid] = tx;

      await box.delete(tx.tid);
      expect(client.lastOp, equals(CoreIpcAction.delete));
      expect(box.get('idY'), isNull);
    });

    test('addAll sends multiPut and merges items', () async {
      final txs = [makeTx('a', balance: 1.0), makeTx('b', balance: 2.0)];
      await box.addAll(txs);

      expect(client.lastOp, equals(CoreIpcAction.multiPut));
      expect(box.length, equals(2));
    });

    test('replace sends replace and resets items', () async {
      box.items['old'] = makeTx('old', balance: 3.0);
      final txs = [makeTx('new1', balance: 4.0), makeTx('new2', balance: 5.0)];
      await box.replace(txs);

      expect(client.lastOp, equals(CoreIpcAction.replace));
      expect(box.length, equals(2));
      expect(box.get('new1')?.tid, equals('new1'));
    });

    test('receive handles put/delete/clear/multiPut/replace', () {
      // put
      final putEvent = CoreIpcBroadcastEvent(op: CoreIpcAction.put.code, action: 'transactions_box', key: 'id1', payload: makeTx('id1'));
      box.receive(putEvent);
      expect(box.get('id1')?.tid, equals('id1'));

      // delete
      final delEvent = CoreIpcBroadcastEvent(op: CoreIpcAction.delete.code, action: 'transactions_box', key: 'id1', payload: null);
      box.receive(delEvent);
      expect(box.get('id1'), isNull);

      // clear
      box.items['x'] = makeTx('x');
      final clearEvent = CoreIpcBroadcastEvent(op: CoreIpcAction.clear.code, action: 'transactions_box', key: '', payload: null);
      box.receive(clearEvent);
      expect(box.isEmpty, isTrue);

      // multiPut
      final multiEvent = CoreIpcBroadcastEvent(
        op: CoreIpcAction.multiPut.code,
        action: 'transactions_box',
        key: '',
        payload: [makeTx('a'), makeTx('b')],
      );
      box.receive(multiEvent);
      expect(box.length, equals(2));

      // replace
      final replaceEvent = CoreIpcBroadcastEvent(
        op: CoreIpcAction.replace.code,
        action: 'transactions_box',
        key: '',
        payload: [makeTx('c')],
      );
      box.receive(replaceEvent);
      expect(box.length, equals(1));
      expect(box.get('c')?.tid, equals('c'));
    });

    test('add/update/remove delegate to put/delete', () async {
      final tx = makeTx('idZ', balance: 11.0);
      await box.add(tx);
      expect(box.get('idZ'), equals(tx));

      final updated = makeTx('idZ', balance: 12.0);
      await box.update(updated);
      expect(box.get('idZ')?.balance, equals(12.0));

      await box.remove(updated);
      expect(box.get('idZ'), isNull);
    });
  });

  group('CoreIpcBroadcastEvent', () {
    test('actionCode resolves correctly from op code', () {
      final eventPut = CoreIpcBroadcastEvent(op: CoreIpcAction.put.code, action: 'transactions_box', key: 'id1', payload: makeTx('id1'));
      expect(eventPut.actionCode, equals(CoreIpcAction.put));

      final eventDelete = CoreIpcBroadcastEvent(op: CoreIpcAction.delete.code, action: 'transactions_box', key: 'id2', payload: null);
      expect(eventDelete.actionCode, equals(CoreIpcAction.delete));

      final eventClear = CoreIpcBroadcastEvent(op: CoreIpcAction.clear.code, action: 'transactions_box', key: '', payload: null);
      expect(eventClear.actionCode, equals(CoreIpcAction.clear));

      final eventMultiPut = CoreIpcBroadcastEvent(
        op: CoreIpcAction.multiPut.code,
        action: 'transactions_box',
        key: '',
        payload: [makeTx('a'), makeTx('b')],
      );
      expect(eventMultiPut.actionCode, equals(CoreIpcAction.multiPut));

      final eventReplace = CoreIpcBroadcastEvent(
        op: CoreIpcAction.replace.code,
        action: 'transactions_box',
        key: '',
        payload: [makeTx('c')],
      );
      expect(eventReplace.actionCode, equals(CoreIpcAction.replace));
    });

    test('fields are stored and accessible', () {
      final tx = makeTx('idX');
      final event = CoreIpcBroadcastEvent(op: CoreIpcAction.put.code, action: 'transactions_box', key: tx.tid, payload: tx);

      expect(event.op, equals(CoreIpcAction.put.code));
      expect(event.action, equals('transactions_box'));
      expect(event.key, equals('idX'));
      expect(event.payload, equals(tx));
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
      final pipeName = await _testPipeName();
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
        return SystemUnlockStatus.success;
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
      expect(response.length, equals(32));
    });

    test('broadcasts events to connected clients', () async {
      // Define the variables and keys
      final pipeName = await _testPipeName();
      final keyBytes = Uint8List.fromList([1, 2, 3]);

      // Booting the server
      CoreMode.isServer = true;
      final server = CoreIpcServer();
      server.pipeName = pipeName;
      server.unlocker = (bytes) async => SystemUnlockStatus.success;
      server.database = DatabaseFaker(CoreIpcBoxes(), CoreIpcAdapters(), CoreIpcMigration());
      await server.start();
      final sessionKey = server.sessionKey;

      // Booting the client 1
      await Future.delayed(const Duration(milliseconds: 150));
      final client1 = CoreIpcClient(CoreIpcAdapters());
      client1.pipeName = pipeName;
      await client1.start();

      // Registering the client 1 broadcast listener
      final client1Subscription = client1.onBroadcast.listen((event) {
        expect(event.action, equals('transactions_box'));
        expect(event.key, equals('52'));
        final data = event.payload as TransactionsModel;
        expect(data.uuid, equals('52'));
        expect(data.balance, equals(3.0));
        expect(data, isA<TransactionsModel>());
      });

      // Handshaking for client 1
      await Future.delayed(const Duration(milliseconds: 150));
      final handshakeBytes = await client1.send(op: CoreIpcAction.unlock, action: 'auth', key: 'unlock', payload: keyBytes);
      expect(handshakeBytes, equals(sessionKey));
      client1.localKey = keyBytes;
      client1.sessionKey = handshakeBytes;

      // Booting the client 2
      await Future.delayed(const Duration(milliseconds: 150));
      CoreMode.isServer = false;
      final client2 = CoreIpcClient(CoreIpcAdapters());
      client2.pipeName = pipeName;
      await client2.start();

      // Registering client 2 broadcast listener
      final client2Subscription = client2.onBroadcast.listen((event) {
        expect(event.action, equals('transactions_box'));
        expect(event.key, equals('42'));
        final data = event.payload as TransactionsModel;
        expect(data.uuid, equals('42'));
        expect(data.balance, equals(6.0));
        expect(data, isA<TransactionsModel>());
      });

      // Client 2 handshaking
      await Future.delayed(const Duration(milliseconds: 150));
      final handshakeBytes2 = await client2.send(op: CoreIpcAction.unlock, action: 'auth', key: 'unlock', payload: keyBytes);
      expect(handshakeBytes2, equals(sessionKey));
      client2.localKey = keyBytes;
      client2.sessionKey = handshakeBytes2;

      // Registering teardown
      addTearDown(() async {
        await client1Subscription.cancel();
        await client2Subscription.cancel();
        await client1.dispose();
        await client2.dispose();
        await server.dispose();
      });

      // Testing sending via client 1
      await Future.delayed(const Duration(milliseconds: 150));
      final tx1 = makeTx("42", balance: 6.0);
      client1.send(op: CoreIpcAction.put, action: 'transactions_box', key: '42', payload: tx1);

      // Testing sending via client 2
      await Future.delayed(const Duration(milliseconds: 150));
      final tx2 = makeTx("52", balance: 3.0);
      client2.send(op: CoreIpcAction.put, action: 'transactions_box', key: '52', payload: tx2);
    });
  });
}
