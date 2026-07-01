import 'dart:typed_data';

import '../../abstracts/models/with_id.dart';
import '../../abstracts/box.dart';
import '../../runtime/locator.dart';
import '../../log.dart';

import '../action.dart';
import '../client.dart';
import '../registry.dart';
import '../protocol/writer.dart';
import '../protocol/reader.dart';

class CoreIpcBoxStandard<T extends CoreModelWithId> extends CoreBaseBox<T> {
  CoreIpcBoxStandard(super.boxName);

  CoreIpcClient get ipc => locator<CoreIpcClient>();

  @override
  Future<void> init() async {
    final resultBytes = await ipc.send(op: CoreIpcAction.extract, action: boxName);
    unpackBytes(resultBytes);
    logln("[IPC] Initialized standard box: $boxName|${items.length}");
  }

  @override
  Future<void> put(dynamic id, T value) async {
    final writer = CoreIpcWriter();
    final boxAdapter = CoreIpcRegistry.getAdapter(boxName);
    boxAdapter.write(writer, value);

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.put, action: boxName, key: id, payload: bytes);

    items[id] = value;
  }

  @override
  Future<int> clear() async {
    final resultBytes = await ipc.send(op: CoreIpcAction.clear, action: boxName);
    if (resultBytes.isEmpty || resultBytes.length < 4) {
      items.clear();
      return 0;
    }
    final count = ByteData.sublistView(resultBytes).getInt32(0, Endian.big);
    items.clear();

    return count;
  }

  @override
  Future<void> delete(dynamic id) async {
    await ipc.send(op: CoreIpcAction.delete, action: boxName, key: id);
    items.remove(id);
  }

  @override
  Future<void> flush() async {
    await ipc.send(op: CoreIpcAction.flush, action: boxName);
  }

  @override
  Future<void> addAll(List<T> values) async {
    if (values.isEmpty) return;

    final writer = CoreIpcWriter();
    final boxAdapter = CoreIpcRegistry.getAdapter(boxName);

    writer.writeInt(values.length);

    for (final value in values) {
      boxAdapter.write(writer, value);
    }

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.multiPut, action: boxName, payload: bytes);

    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  @override
  Future<void> replace(List<T> values) async {
    final writer = CoreIpcWriter();
    final boxAdapter = CoreIpcRegistry.getAdapter(boxName);

    writer.writeInt(values.length);

    for (final value in values) {
      boxAdapter.write(writer, value);
    }

    final bytes = writer.toBytes();
    await ipc.send(op: CoreIpcAction.replace, action: boxName, payload: bytes);

    items.clear();
    for (final value in values) {
      items[value.uuid] = value;
    }
  }

  @override
  unpackBytes(Uint8List resultBytes) {
    final reader = CoreIpcReader(resultBytes);
    final int count = reader.readInt();
    final adapter = CoreIpcRegistry.getAdapter(boxName);

    items.clear();

    for (var i = 0; i < count; i++) {
      final dynamic decodedItem = reader.read(null, adapter);
      if (decodedItem is T) {
        items[decodedItem.uuid] = decodedItem;
      }
    }
  }

  Future<void> add(T tx) async {
    await put(tx.uuid, tx);
  }

  Future<void> update(T tx) async {
    await add(tx);
  }

  Future<void> remove(T tx) async {
    await delete(tx.uuid);
  }
}
