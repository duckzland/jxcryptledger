import 'dart:typed_data';

import 'package:jxledger/ipc/abstracts/database.dart';
import 'package:jxledger/ipc/status/unlock.dart';

class IpcDatabaseFaker extends IpcDatabase {
  IpcDatabaseFaker(super.boxes, super.adapters, super.migration, super.path);

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<IpcStatusUnlock> unlock(Uint8List keyBytes) async {
    unlocked = IpcStatusUnlock.success;
    return IpcStatusUnlock.success;
  }

  @override
  Future<void> dispose() async {
    initialized = false;
  }

  @override
  Future<void> delete(String boxName, dynamic key) async {
    return;
  }

  @override
  Future<void> put(String boxName, dynamic key, dynamic value) async {
    return;
  }

  @override
  Future<void> clear(String boxName) async {
    return;
  }

  @override
  Future<void> flush(String boxName) async {
    return;
  }

  @override
  Iterable<dynamic> keys(String boxName) {
    return {};
  }

  @override
  dynamic get(String boxName, dynamic id) {
    return null;
  }
}
