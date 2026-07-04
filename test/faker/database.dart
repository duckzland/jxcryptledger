import 'dart:typed_data';

import 'package:jxledger/core/ipc/database/database.dart';
import 'package:jxledger/system/unlock/status.dart';

class DatabaseFaker extends CoreIpcDatabase {
  DatabaseFaker(super.boxes, super.adapters, super.migration);

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<SystemUnlockStatus> unlock(Uint8List keyBytes) async {
    unlocked = true;
    return SystemUnlockStatus.success;
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
