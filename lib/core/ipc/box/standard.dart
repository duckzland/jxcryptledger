import 'dart:typed_data';

import '../../abstracts/models/with_id.dart';
import '../../abstracts/box.dart';
import '../../locator.dart';
import '../../log.dart';

import '../client.dart';
import '../registry.dart';
import '../protocol/writer.dart';
import '../protocol/reader.dart';

class CoreIpcBoxStandard<T extends CoreModelWithId> extends CoreBaseBox<T> {
  CoreIpcBoxStandard(super.boxName);

  final CoreIpcClient ipc = locator<CoreIpcClient>();

  @override
  Future<void> init() async {
    final resultBytes = await ipc.sendAction(op: 0x06, box: boxName);
    if (resultBytes.isEmpty) {
      items.clear();
      return;
    }

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

    logln("[IPC] Initialized standard box: $boxName|${items.length}");
  }

  @override
  Future<void> put(dynamic id, T value) async {
    final writer = CoreIpcWriter();
    final boxAdapter = CoreIpcRegistry.getAdapter(boxName);
    boxAdapter.write(writer, value);

    final bytes = writer.toBytes();
    await ipc.sendAction(op: 0x02, box: boxName, key: id, value: bytes);

    items[id] = value;
  }

  @override
  Future<int> clear() async {
    final resultBytes = await ipc.sendAction(op: 0x04, box: boxName);
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
    await ipc.sendAction(op: 0x03, box: boxName, key: id);
    items.remove(id);
  }

  @override
  Future<void> flush() async {
    await ipc.sendAction(op: 0x05, box: boxName);
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
