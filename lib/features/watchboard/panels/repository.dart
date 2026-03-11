import 'dart:convert';
import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../../core/log.dart';
import 'model.dart';

class PanelsRepository {
  static const String boxName = 'panels_box';
  final bool debugLogs = true;

  Box<PanelsModel> get _box => Hive.box<PanelsModel>(boxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<PanelsModel>(boxName);
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

  Future<void> add(PanelsModel tx) async {
    if (debugLogs) {
      logln(
        '[ADD] tid=${tx.tid}|srId=${tx.srId}|srAmount=${tx.srAmount}|rrId=${tx.rrId}|digit=${tx.digit}|rate=${tx.rate}|order=${tx.order}',
      );
    }
    await _box.put(tx.tid, tx);
  }

  Future<void> update(PanelsModel tx) async {
    if (debugLogs) {
      logln(
        '[UPDATE] tid=${tx.tid}|srId=${tx.srId}|srAmount=${tx.srAmount}|rrId=${tx.rrId}|digit=${tx.digit}|rate=${tx.rate}|order=${tx.order}',
      );
    }
    await _box.put(tx.tid, tx);
  }

  Future<void> delete(PanelsModel tx) async {
    if (debugLogs) {
      logln('[DELETE] tid=${tx.tid}');
    }
    await _box.delete(tx.tid);
  }

  Future<String> export() async {
    final items = _box.values.toList();
    final jsonList = items.map((tx) => tx.toJson()).toList();
    return jsonEncode(jsonList);
  }

  Future<void> import(String rawJson) async {
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    final txs = decoded.map((e) => PanelsModel.fromJson(e as Map<String, dynamic>)).toList();

    await _box.clear();
    for (final tx in txs) {
      await _box.put(tx.tid, tx);
    }
  }

  Future<void> clear() async {
    await _box.clear();
  }

  Future<PanelsModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<List<PanelsModel>> getAll() async {
    return _box.values.toList();
  }

  bool isEmpty() {
    return _box.isEmpty;
  }
}
