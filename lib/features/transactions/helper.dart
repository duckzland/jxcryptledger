import 'package:decimal/decimal.dart';

import 'model.dart';

class TransactionsHelper {
  TransactionsHelper._();

  static List<TransactionsModel> collectAllRoots({
    Map<String, Map<String, TransactionsModel>>? rootMap,
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (rootMap != null) {
      final roots = <TransactionsModel>[];
      for (final entry in rootMap.entries) {
        final root = entry.value[entry.key];
        if (root != null && root.isRoot) {
          roots.add(root);
        }
      }
      return roots;
    }

    final values = txsMap?.values ?? txs;
    if (values == null) return const <TransactionsModel>[];

    return values.where((tx) => tx.isRoot).toList();
  }

  static List<TransactionsModel> collectAllLeaves(
    TransactionsModel parent, {
    Map<String, List<TransactionsModel>>? childrenMap,
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (childrenMap == null) {
      final values = txsMap?.values ?? txs;
      if (values == null) return const <TransactionsModel>[];

      childrenMap = <String, List<TransactionsModel>>{};
      for (final item in values) {
        if (item.pid.isNotEmpty && item.pid != '0') {
          (childrenMap[item.pid] ??= <TransactionsModel>[]).add(item);
        }
      }
    }

    final descendants = <TransactionsModel>[];

    void dfs(TransactionsModel node) {
      final children = childrenMap![node.tid];
      if (children == null || children.isEmpty) return;

      for (final child in children) {
        descendants.add(child);
        dfs(child);
      }
    }

    dfs(parent);
    return descendants;
  }

  static List<TransactionsModel> collectRootTreeLeaves(
    TransactionsModel parent, {
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    final values = txsMap?.values ?? txs;
    if (values == null) return const <TransactionsModel>[];

    return values.where((tx) => !tx.isRoot && tx.rid == parent.tid).toList();
  }

  static List<TransactionsModel> collectTerminalLeaves(
    TransactionsModel parent, {
    Map<String, List<TransactionsModel>>? childrenMap,
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (childrenMap == null) {
      final values = txsMap?.values ?? txs;
      if (values == null) return const <TransactionsModel>[];

      childrenMap = <String, List<TransactionsModel>>{};
      for (final item in values) {
        if (item.pid.isNotEmpty && item.pid != '0') {
          (childrenMap[item.pid] ??= <TransactionsModel>[]).add(item);
        }
      }
    }

    final leaves = <TransactionsModel>[];

    void dfs(TransactionsModel node) {
      final children = childrenMap![node.tid];
      if (children == null || children.isEmpty) {
        if (node.tid != parent.tid && !node.isRoot) {
          leaves.add(node);
        }
        return;
      }

      for (final child in children) {
        dfs(child);
      }
    }

    dfs(parent);
    return leaves;
  }

  static List<TransactionsModel> collectAllTerminalLeaves({
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
    Map<String, List<TransactionsModel>>? childrenMap,
  }) {
    final values = txsMap?.values ?? txs;
    if (values == null) return const <TransactionsModel>[];

    if (childrenMap == null) {
      final parentIds = <String>{};
      for (final item in values) {
        if (item.pid.isNotEmpty && item.pid != '0') {
          parentIds.add(item.pid);
        }
      }
      return [
        for (final tx in values)
          if (!tx.isRoot && !parentIds.contains(tx.tid)) tx,
      ];
    }

    return [
      for (final tx in values)
        if (!tx.isRoot && (childrenMap[tx.tid]?.isEmpty ?? true)) tx,
    ];
  }

  static List<TransactionsModel> collectInBetweenLeaves(
    TransactionsModel start,
    TransactionsModel end, {
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (txs == null && txsMap == null) return const <TransactionsModel>[];

    txsMap ??= {for (final item in txs!) item.tid: item};

    final ascendants = <TransactionsModel>[];
    TransactionsModel? current = start;

    while (current != null && !current.isRoot) {
      if (current.pid.isEmpty || current.pid == '0') break;
      final parent = txsMap[current.pid];
      if (parent == null) break;

      ascendants.add(parent);

      if (parent.tid == end.tid) break;

      current = parent;
    }

    return ascendants;
  }

  static List<TransactionsModel> getLeaf(
    TransactionsModel tx, {
    Map<String, List<TransactionsModel>>? childrenMap,
    Iterable<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (childrenMap != null) {
      return childrenMap[tx.tid] ?? const <TransactionsModel>[];
    }

    final values = txsMap?.values ?? txs;
    if (values == null) return const <TransactionsModel>[];

    return [
      for (final item in values)
        if (item.pid == tx.tid) item,
    ];
  }

  static TransactionsModel? getCloseTargetParent(
    TransactionsModel tx, {
    List<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    if (tx.isRoot) return null;
    if (txs == null && txsMap == null) return null;

    txsMap ??= {
      for (final item in txs!)
        if (item.rid == tx.rid || item.tid == tx.rid) item.tid: item,
    };

    String pid = tx.pid;
    TransactionsModel? target;
    Decimal rr = tx.rrAmount;

    while (pid.isNotEmpty && pid != '0') {
      final p = txsMap[pid];
      if (p == null) break;

      if (p.rrId == tx.rrId && p.rrAmount <= rr) {
        target = p;
        rr = p.rrAmount;
      }

      pid = p.pid;
    }

    return target;
  }
}
