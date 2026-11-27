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
    removeByTid(tx.tid, tx: tx);
  }

  void removeByTid(String tid, {TransactionsModel? tx}) {
    if (!isInitialized) return;

    final target = tx ?? _byTid![tid];
    if (target == null) return;

    _byPid![target.pid]?.removeWhere((item) => item.tid == tid);

    if (target.isRoot) {
      _byRid!.remove(tid);
    } else {
      _byRid![target.rid]?.remove(tid);
    }
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
