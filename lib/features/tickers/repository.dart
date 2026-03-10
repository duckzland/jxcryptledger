import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../core/log.dart';
import 'model.dart';

class TickersRepository {
  static const String boxName = 'tickers_box';
  final bool debugLogs = true;

  Box<TickersModel> get _box => Hive.box<TickersModel>(boxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TickersModel>(boxName);
    }
  }

  String generateTid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    while (true) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final timePart = now.toRadixString(36).padLeft(4, '0');
      final timeSuffix = timePart.substring(timePart.length - 4);
      final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      final id = '$timeSuffix$randomPart';
      if (!_box.containsKey(id)) {
        if (debugLogs) {
          logln('Generated unique ID: $id');
        }
        return id;
      }

      if (debugLogs) {
        logln('Collision detected for $id, retrying...');
      }
    }
  }

  Future<void> add(TickersModel tx) async {
    if (debugLogs) {
      logln('[ADD] tid=${tx.tid}|type=${tx.type}|format=${tx.format}|title=${tx.title}|value=${tx.value}|order=${tx.order}');
    }
    await _box.put(tx.tid, tx);
  }

  Future<void> update(TickersModel tx) async {
    if (debugLogs) {
      logln('[UPDATE] tid=${tx.tid}|type=${tx.type}|format=${tx.format}|title=${tx.title}|value=${tx.value}|order=${tx.order}');
    }
    await _box.put(tx.tid, tx);
  }

  Future<void> delete(TickersModel tx) async {
    if (debugLogs) {
      logln('[DELETE] tid=${tx.tid}');
    }
    await _box.delete(tx.tid);
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<TickersModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<List<TickersModel>> getAll() async {
    return _box.values.toList();
  }

  Future<void> updateByType(int type, String newVal) async {
    TickersModel? model;
    try {
      model = _box.values.firstWhere((m) => m.type == type);
    } catch (_) {
      return;
    }

    model.value = newVal;
    await _box.put(model.tid, model);
  }

  bool isEmpty() {
    return _box.isEmpty;
  }
}
