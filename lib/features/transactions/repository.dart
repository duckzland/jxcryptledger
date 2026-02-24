import 'package:hive_ce/hive_ce.dart';

import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';

  final FilterIsolate _filter = FilterIsolate();

  Box<TransactionsModel> get _box => Hive.box<TransactionsModel>(boxName);

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
    }
  }

  Future<TransactionsModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<void> add(TransactionsModel tx) async {
    logln(
      '[ADD] tid=${tx.tid} pid=${tx.pid} rid=${tx.rid} '
      'srId=${tx.srId} srAmount=${tx.srAmount} '
      'rrId=${tx.rrId} rrAmount=${tx.rrAmount} '
      'balance=${tx.balance} status=${tx.status} '
      'timestamp=${tx.timestamp}',
    );
    if (tx.srId == 0 || tx.rrId == 0) {
      logln('Invalid tx: srId=${tx.srId}, rrId=${tx.rrId}');
      return;
    }

    await _box.put(tx.tid, tx);
  }

  Future<void> update(TransactionsModel tx) async {
    logln(
      '[UPDATE] tid=${tx.tid} pid=${tx.pid} rid=${tx.rid} '
      'srId=${tx.srId} srAmount=${tx.srAmount} '
      'rrId=${tx.rrId} rrAmount=${tx.rrAmount} '
      'balance=${tx.balance} status=${tx.status} '
      'timestamp=${tx.timestamp}',
    );
    if (tx.srId == 0 || tx.rrId == 0) {
      logln('Invalid tx: srId=${tx.srId}, rrId=${tx.rrId}');
      return;
    }
    await _box.put(tx.tid, tx);
  }

  Future<void> delete(String tid) async {
    await _box.delete(tid);
  }

  Future<List<TransactionsModel>> getAll() async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }
}
