import '../../core/log.dart';
import 'model.dart';

class TransactionsIndex {
  final Map<String, TransactionsModel> Function() _sourceExtractor;

  Map<String, TransactionsModel>? _byTid;
  Map<String, List<TransactionsModel>>? _byPid;
  Map<String, Map<String, TransactionsModel>>? _byRid;

  TransactionsIndex(this._sourceExtractor);

  bool get isInitialized => _byTid != null;

  Map<String, TransactionsModel> get byTid {
    _ensureInitialized();
    return _byTid!;
  }

  Map<String, List<TransactionsModel>> get byPid {
    _ensureInitialized();
    return _byPid!;
  }

  Map<String, Map<String, TransactionsModel>> get byRid {
    _ensureInitialized();
    return _byRid!;
  }

  void invalidate() {
    _byTid = null;
    _byPid = null;
    _byRid = null;
  }

  void update(TransactionsModel tx) {
    if (!isInitialized) return;

    _byPid![tx.pid]?.removeWhere((item) => item.tid == tx.tid);

    (_byRid![tx.isRoot ? tx.tid : tx.rid] ??= <String, TransactionsModel>{})[tx.tid] = tx;
    (_byPid![tx.pid] ??= <TransactionsModel>[]).add(tx);
  }

  void remove(TransactionsModel tx) {
    removeByTid(tx.tid);
  }

  void removeByTid(String tid) {
    if (!isInitialized) return;

    final orphanedTids = <String>{...?_byRid![tid]?.keys, ...?_byPid![tid]?.map((tx) => tx.tid)};

    _byTid!.remove(tid);
    for (final childTid in orphanedTids) {
      _byTid!.remove(childTid);
    }

    _byRid!.remove(tid);
    _byPid!.remove(tid);

    _byPid!.removeWhere((pid, txList) {
      txList.removeWhere((tx) => tx.tid == tid || orphanedTids.contains(tx.tid));
      return txList.isEmpty;
    });

    _byRid!.removeWhere((rid, txMap) {
      txMap.remove(tid);
      orphanedTids.forEach(txMap.remove);
      return txMap.isEmpty;
    });
  }

  void generate() {
    final source = _sourceExtractor();
    final roots = <String, Map<String, TransactionsModel>>{};
    final children = <String, List<TransactionsModel>>{};

    for (final tx in source.values) {
      (roots[tx.isRoot ? tx.tid : tx.rid] ??= <String, TransactionsModel>{})[tx.tid] = tx;
      (children[tx.pid] ??= <TransactionsModel>[]).add(tx);
    }

    _byTid = source;
    _byPid = children;
    _byRid = roots;

    logln("Generating tx indexes", "INDEXING");
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      generate();
    }
  }
}
