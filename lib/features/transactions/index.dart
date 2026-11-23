import '../../core/log.dart';
import 'model.dart';

class TransactionsIndex {
  final Iterable<TransactionsModel> Function() _sourceExtractor;

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

    final old = _byTid![tx.tid];
    if (old != null) {
      _byPid![old.pid]?.removeWhere((item) => item.tid == old.tid);
    }

    _byTid![tx.tid] = tx;
    (_byRid![tx.isRoot ? tx.tid : tx.rid] ??= <String, TransactionsModel>{})[tx.tid] = tx;
    (_byPid![tx.pid] ??= <TransactionsModel>[]).add(tx);
  }

  void remove(TransactionsModel tx) {
    removeByTid(tx.tid);
  }

  void removeByTid(String tid) {
    if (!isInitialized) return;

    final tx = _byTid!.remove(tid);
    if (tx == null) return;

    _byPid![tx.pid]?.removeWhere((item) => item.tid == tid);

    if (tx.isRoot) {
      _byRid!.remove(tid);
    } else {
      _byRid![tx.rid]?.remove(tid);
    }
  }

  void generate() {
    final indexed = <String, TransactionsModel>{};
    final roots = <String, Map<String, TransactionsModel>>{};
    final children = <String, List<TransactionsModel>>{};

    for (final tx in _sourceExtractor()) {
      indexed[tx.tid] = tx;
      (roots[tx.isRoot ? tx.tid : tx.rid] ??= <String, TransactionsModel>{})[tx.tid] = tx;
      (children[tx.pid] ??= <TransactionsModel>[]).add(tx);
    }

    _byTid = indexed;
    _byPid = children;
    _byRid = roots;

    logln("Generating tx indexes", "INDEXING");
  }

  void _ensureInitialized() {
    if (_byTid == null) {
      generate();
    }
  }
}
