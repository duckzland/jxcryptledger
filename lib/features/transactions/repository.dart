import 'dart:math';

import 'package:hive_ce/hive_ce.dart';

import '../../app/exceptions.dart';
import '../../core/filtering.dart';
import '../../core/log.dart';
import 'model.dart';

class TransactionsRepository {
  static const String boxName = 'transactions_box';
  final bool debugLogs = true;

  final FilterIsolate _filter = FilterIsolate();

  Box<TransactionsModel> get _box => Hive.box<TransactionsModel>(boxName);

  Future<void> init() async {
    await _filter.init();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<TransactionsModel>(boxName);
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

  Future<TransactionsModel?> get(String tid) async {
    return _box.get(tid);
  }

  Future<void> add(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[ADD] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;

    bool isClosable;
    try {
      isClosable = await canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await canAdd(ntx);

    await _box.put(ntx.tid, ntx);
    await _box.flush();
  }

  Future<void> update(TransactionsModel tx) async {
    if (debugLogs) {
      logln(
        '[UPDATE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    TransactionsModel ntx = tx;
    bool isClosable;
    try {
      isClosable = await canClose(ntx);
    } catch (e) {
      isClosable = false;
    }

    if (tx.isClosable != isClosable) {
      ntx = ntx.copyWith(closable: isClosable);
    }

    await canUpdate(ntx);

    await _box.put(ntx.tid, ntx);
  }

  Future<void> delete(TransactionsModel tx) async {
    await canDelete(tx);

    if (debugLogs) {
      logln(
        '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    // This is to preseve tree sanity!
    _deleteLeaves(tx);

    await _box.delete(tx.tid);
  }

  Future<void> close(TransactionsModel tx) async {
    await canClose(tx);

    TransactionsModel? otx = _box.get(tx.tid);
    if (otx == null) {
      return; // canClose already check and throw
    }

    TransactionsModel? target = await getCloseTargetParent(otx);
    if (target == null) {
      return; // canClose already check and throw
    }

    final leaves = await collectTerminalLeaves(target);
    final allClosed =
        leaves.isNotEmpty &&
        leaves
            // Current tx hasn't mutate status yet thus ignore it!
            .where((leaf) => leaf.tid != otx.tid)
            .every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    final newStatus = allClosed ? TransactionStatus.active.index : TransactionStatus.partial.index;
    final updatedTarget = target.copyWith(balance: target.balance + tx.balance, status: newStatus);

    final closedTx = tx.copyWith(balance: 0, status: TransactionStatus.closed.index);

    if (debugLogs) {
      logln(
        '[CLOSING] ${tx.tid}|${tx.pid}|${tx.rid}|{tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
      );
    }

    await _box.put(closedTx.tid, closedTx);
    await _box.put(updatedTarget.tid, updatedTarget);
  }

  Future<List<TransactionsModel>> getAll() async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<List<TransactionsModel>> getLeaf(TransactionsModel tx) async {
    final list = <TransactionsModel>[];
    for (final key in _box.keys) {
      final ltx = _box.get(key);
      if (ltx != null && ltx.pid == tx.tid) list.add(ltx);
    }
    return list;
  }

  Future<List<TransactionsModel>> filter(String query) async {
    final all = await getAll();
    final maps = all.map((e) => e.toMap()).toList();

    final filteredMaps = await _filter.filter(maps, query);
    return filteredMaps.map(TransactionsModel.fromMap).toList();
  }

  Future<List<TransactionsModel>> collectTerminalLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final Map<String, List<TransactionsModel>> childrenMap = {};
    for (final tx in all) {
      childrenMap.putIfAbsent(tx.pid, () => []).add(tx);
    }

    List<TransactionsModel> dfs(TransactionsModel node) {
      final children = childrenMap[node.tid] ?? [];

      if (children.isEmpty) {
        if (node.tid == parent.tid) return [];
        if (node.isRoot) return [];
        return [node];
      }

      final leaves = <TransactionsModel>[];
      for (final child in children) {
        leaves.addAll(dfs(child));
      }
      return leaves;
    }

    return dfs(parent);
  }

  Future<List<TransactionsModel>> collectAllLeaves(TransactionsModel parent) async {
    final all = await getAll();

    final Map<String, List<TransactionsModel>> childrenMap = {};
    for (final tx in all) {
      childrenMap.putIfAbsent(tx.pid, () => []).add(tx);
    }

    List<TransactionsModel> dfs(TransactionsModel node) {
      final children = childrenMap[node.tid] ?? [];

      if (children.isEmpty) {
        return (node.tid == parent.tid) ? [] : [node];
      }

      final leaves = <TransactionsModel>[];
      for (final child in children) {
        leaves.addAll(dfs(child));
      }

      return leaves;
    }

    return dfs(parent);
  }

  Future<TransactionsModel?> getCloseTargetParent(TransactionsModel tx) async {
    if (tx.isRoot) {
      return null;
    }

    final all = await getAll();

    final Map<String, TransactionsModel> byTid = {for (final t in all) t.tid: t};

    TransactionsModel? parent;
    String? pid = tx.pid;

    while (pid != null && pid.isNotEmpty) {
      final p = byTid[pid];
      if (p == null) break;

      if (p.rrId == tx.rrId) {
        parent = p;
        break;
      }

      pid = p.pid;
    }

    if (parent == null) {
      final roots = all.where((t) => t.isRoot && t.tid == tx.rid);

      if (roots.isNotEmpty) {
        final root = roots.first;
        if (root.rrId == tx.rrId) {
          parent = root;
        }
      }
    }

    return parent;
  }

  Future<bool> canAdd(TransactionsModel tx) async {
    final ptx = _box.get(tx.pid);
    final rtx = _box.get(tx.rid);

    if (tx.tid == '0') {
      throw ValidationException(AppErrorCode.txAddInvalidTid, "Add failed: tid == '0'", "This transaction is invalid.", silent: !debugLogs);
    }

    if (tx.pid == '0' && tx.rid != '0') {
      throw ValidationException(
        AppErrorCode.txAddPidZeroRidNotZero,
        "Add failed: pid=0 but rid!=0 (pid=${tx.pid}, rid=${tx.rid})",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rid == '0' && tx.pid != '0') {
      throw ValidationException(
        AppErrorCode.txAddRidZeroPidNotZero,
        "Add failed: rid=0 but pid!=0 (pid=${tx.pid}, rid=${tx.rid})",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txAddInvalidFields,
        "Add failed: invalid required fields (tid=${tx.tid})",
        "Some required transaction details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Update failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Invalid transaction, same source and target coin.",
        silent: !debugLogs,
      );
    }

    if (tx.statusEnum != TransactionStatus.active) {
      throw ValidationException(
        AppErrorCode.txAddStatusNotActive,
        "Add failed: new transaction must be active (status=${tx.statusEnum})",
        "A new transaction must start as active.",
        silent: !debugLogs,
      );
    }

    if (tx.isRoot) {
      if (tx.balance != tx.rrAmount) {
        throw ValidationException(
          AppErrorCode.txAddRootBalanceMismatch,
          "Add failed: root balance mismatch (balance=${tx.balance}, rrAmount=${tx.rrAmount})",
          "The transaction balance does not match the expected amount.",
          silent: !debugLogs,
        );
      }

      if (tx.closable != true) {
        throw ValidationException(
          AppErrorCode.txAddRootNotClosable,
          "Add failed: root must be closable=true (tid=${tx.tid})",
          "This transaction must be marked as closable.",
          silent: !debugLogs,
        );
      }
    }

    if (tx.isLeaf) {
      final targetCloser = await getCloseTargetParent(tx);

      if (rtx == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafMissingRoot,
          "Add failed: missing root (rtx == null, rid=${tx.rid})",
          "This transaction is not linked correctly.",
          silent: !debugLogs,
        );
      }

      if (ptx == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafMissingParent,
          "Add failed: missing parent (ptx == null, pid=${tx.pid})",
          "This transaction is not linked correctly.",
          silent: !debugLogs,
        );
      }

      if (tx.srId != ptx.rrId) {
        throw ValidationException(
          AppErrorCode.txAddLeafSrIdMismatch,
          "Add failed: srId=${tx.srId} does not match parent.rrId=${ptx.rrId}",
          "This transaction does not match the expected account.",
          silent: !debugLogs,
        );
      }

      if (tx.srAmount > ptx.balance) {
        throw ValidationException(
          AppErrorCode.txAddLeafAmountExceedsBalance,
          "Add failed: srAmount=${tx.srAmount} exceeds parent.balance=${ptx.balance}",
          "The transaction amount exceeds the available balance.",
          silent: !debugLogs,
        );
      }

      if (tx.closable == true && targetCloser == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafClosableNoTarget,
          "Add failed: closable=true but no targetCloser found",
          "This transaction cannot be marked as closable yet.",
          silent: !debugLogs,
        );
      }

      if (tx.closable == false && targetCloser != null) {
        throw ValidationException(
          AppErrorCode.txAddLeafNotClosableHasTarget,
          "Add failed: closable=false but targetCloser exists",
          "This transaction must be marked as closable.",
          silent: !debugLogs,
        );
      }
    }

    return true;
  }

  Future<bool> canDelete(TransactionsModel tx) async {
    if (!tx.isRoot) {
      throw ValidationException(
        AppErrorCode.txDeleteNotRoot,
        "Delete failed: transaction is not root (tid=${tx.tid})",
        "This transaction cannot be deleted.",
        silent: !debugLogs,
      );
    }

    final terminals = await collectTerminalLeaves(tx);
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      throw ValidationException(
        AppErrorCode.txDeleteActiveChildren,
        "Delete failed: active terminal children exist (tid=${tx.tid})",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: !debugLogs,
      );
    }

    final leaves = await collectAllLeaves(tx);
    final allInactive =
        leaves.isEmpty ||
        leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.inactive);

    if (!allInactive) {
      throw ValidationException(
        AppErrorCode.txDeleteInactiveLeaves,
        "Delete failed: some leaves are still active (tid=${tx.tid})",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<bool> canUpdate(TransactionsModel tx) async {
    final otx = _box.get(tx.tid);
    final ptx = _box.get(tx.pid);
    final rtx = _box.get(tx.rid);

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Update failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot update, same source and target coin.",
        silent: !debugLogs,
      );
    }

    if (otx == null) {
      throw ValidationException(
        AppErrorCode.txUpdateNotFound,
        "Update failed: original transaction not found (tid=${tx.tid})",
        "This transaction can no longer be found.",
        silent: !debugLogs,
      );
    }

    if (otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      throw ValidationException(
        AppErrorCode.txUpdateRootPidRid,
        "Update failed: root cannot change pid/rid (tid=${tx.tid})",
        "This transaction cannot be changed in that way.",
        silent: !debugLogs,
      );
    }

    if (otx.isLeaf && (ptx == null || rtx == null)) {
      throw ValidationException(
        AppErrorCode.txUpdateLeafMissingParent,
        "Update failed: leaf missing parent or root (tid=${tx.tid})",
        "This transaction is not linked correctly.",
        silent: !debugLogs,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txUpdateInvalidFields,
        "Update failed: invalid required fields (tid=${tx.tid})",
        "Some required transaction details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    final leaves = await collectTerminalLeaves(tx);
    final targetCloser = await getCloseTargetParent(tx);
    final children = await getLeaf(tx);

    final hasChildren = children.isNotEmpty;
    final allClosed = leaves.isEmpty || leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed);
    final spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final balance = otx.rrAmount - spent;

    if (tx.rrId != otx.rrId || tx.rrAmount != otx.rrAmount || tx.srId != otx.srId || tx.srAmount != otx.srAmount) {
      if (hasChildren) {
        throw ValidationException(
          AppErrorCode.txUpdateCannotChangeSrRr,
          "Update failed: cannot change SR/RR fields when children exist (tid=${tx.tid})",
          "This transaction cannot change its accounts or amounts because related transactions depend on it.",
          silent: !debugLogs,
        );
      }
    }

    if (otx.isLeaf &&
        ptx != null &&
        otx.srAmount != tx.srAmount &&
        otx.srAmount < tx.srAmount &&
        ptx.balance < (tx.srAmount - otx.srAmount)) {
      throw ValidationException(
        AppErrorCode.txUpdateParentInsufficientBalance,
        "Update failed: parent has insufficient balance (tid=${tx.tid})",
        "This transaction cannot change its source amounts because the parent has insufficient balance.",
        silent: !debugLogs,
      );
    }

    if (tx.status != otx.status) {
      switch (tx.statusEnum) {
        case TransactionStatus.inactive:
          if (!hasChildren) {
            throw ValidationException(
              AppErrorCode.txUpdateInactiveRequiresChildren,
              "Update failed: inactive requires children (tid=${tx.tid})",
              "This transaction cannot be marked inactive.",
              silent: !debugLogs,
            );
          }
          if (balance > 0) {
            throw ValidationException(
              AppErrorCode.txUpdateInactiveRequiresZeroBalance,
              "Update failed: inactive requires zero balance (tid=${tx.tid})",
              "This transaction still has remaining balance and cannot be marked inactive.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.active:
          if (!hasChildren && tx.balance <= 0) {
            throw ValidationException(
              AppErrorCode.txUpdateActiveRequiresBalance,
              "Update failed: active requires positive balance (tid=${tx.tid})",
              "This transaction must have a positive balance to remain active.",
              silent: !debugLogs,
            );
          }
          if (hasChildren && !allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdateActiveRequiresChildrenClosed,
              "Update failed: active requires all children closed (tid=${tx.tid})",
              "All related transactions must be completed before this one can be active.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.partial:
          if (!hasChildren) {
            throw ValidationException(
              AppErrorCode.txUpdatePartialRequiresChildren,
              "Update failed: partial requires children (tid=${tx.tid})",
              "This transaction cannot be marked as partially completed.",
              silent: !debugLogs,
            );
          }
          if (hasChildren && allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdatePartialCannotAllClosed,
              "Update failed: partial cannot have all children closed (tid=${tx.tid})",
              "This transaction cannot be marked as partial because all related transactions are already completed.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.closed:
          if (tx.isRoot) {
            throw ValidationException(
              AppErrorCode.txUpdateClosedRoot,
              "Update failed: root cannot be closed (tid=${tx.tid})",
              "This transaction cannot be closed directly.",
              silent: !debugLogs,
            );
          }
          if (targetCloser == null) {
            throw ValidationException(
              AppErrorCode.txUpdateClosedRequiresTarget,
              "Update failed: closed requires targetCloser (tid=${tx.tid})",
              "This transaction is not ready to be closed yet.",
              silent: !debugLogs,
            );
          }
          break;

        case TransactionStatus.unknown:
          break;
      }
    }

    if (tx.closable != otx.closable) {
      switch (tx.closable) {
        case true:
          if (tx.isRoot && !allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdateClosableRootRequiresClosed,
              "Update failed: root closable requires all children closed (tid=${tx.tid})",
              "This transaction cannot be marked as closable yet.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && !otx.isActive) {
            throw ValidationException(
              AppErrorCode.txUpdateClosableLeafRequiresActive,
              "Update failed: leaf closable requires active (tid=${tx.tid})",
              "This transaction must be active before it can be marked as closable.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && targetCloser == null) {
            throw ValidationException(
              AppErrorCode.txUpdateClosableLeafRequiresTarget,
              "Update failed: leaf closable requires targetCloser (tid=${tx.tid})",
              "This transaction cannot be marked as closable yet.",
              silent: !debugLogs,
            );
          }
          break;

        case false:
          if (tx.isRoot && allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdateNotClosableRootAllClosed,
              "Update failed: root cannot be not-closable when all children closed (tid=${tx.tid})",
              "This transaction must remain closable.",
              silent: !debugLogs,
            );
          }
          if (tx.isLeaf && otx.isActive && targetCloser != null) {
            throw ValidationException(
              AppErrorCode.txUpdateNotClosableLeafActiveTarget,
              "Update failed: leaf cannot be not-closable when active with targetCloser (tid=${tx.tid})",
              "This transaction cannot be marked as not closable.",
              silent: !debugLogs,
            );
          }
          break;
      }
    }

    return true;
  }

  Future<bool> canClose(TransactionsModel tx) async {
    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Close failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot close, same source and target coin.",
        silent: !debugLogs,
      );
    }

    if (tx.isRoot) {
      throw ValidationException(
        AppErrorCode.txCloseRoot,
        "Close failed: root cannot be closed (tid=${tx.tid})",
        "This transaction cannot be closed directly.",
        silent: !debugLogs,
      );
    }

    if (!tx.isActive) {
      throw ValidationException(
        AppErrorCode.txCloseNotActive,
        "Close failed: transaction is not active (tid=${tx.tid})",
        "An inactive transaction cannot be closed.",
        silent: !debugLogs,
      );
    }

    final targetCloser = await getCloseTargetParent(tx);

    if (targetCloser == null) {
      throw ValidationException(
        AppErrorCode.txCloseNoTarget,
        "Close failed: no targetCloser found (tid=${tx.tid})",
        "This transaction is not ready to be closed yet.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<bool> canTrade(TransactionsModel tx) async {
    if (tx.tid == '0') {
      throw ValidationException(
        AppErrorCode.txTradeInvalidId,
        "Trade failed: invalid tid='0'",
        "This trade cannot be processed because its ID is invalid.",
        silent: !debugLogs,
      );
    }

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Trade failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot trade for same source and target coin.",
        silent: !debugLogs,
      );
    }

    final otx = _box.get(tx.tid);

    if (otx == null) {
      throw ValidationException(
        AppErrorCode.txTradeNotFound,
        "Trade failed: original transaction not found (tid=${tx.tid})",
        "This trade cannot be processed because the original transaction was not found.",
        silent: !debugLogs,
      );
    }

    if (!otx.isRoot) {
      final ptx = _box.get(tx.pid);
      final rtx = _box.get(tx.rid);

      if (ptx == null || rtx == null) {
        throw ValidationException(
          AppErrorCode.txTradeMissingParent,
          "Trade failed: missing parent or root (tid=${tx.tid})",
          "Invalid transaction cannot be traded.",
          silent: !debugLogs,
        );
      }
    }

    if (!otx.isActive && !otx.isPartial) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidState,
        "Trade failed: transaction not active or partial (tid=${tx.tid})",
        "This trade cannot be processed because the original transaction is not in a valid state.",
        silent: !debugLogs,
      );
    }

    if (otx.rrId <= 0 || otx.srId <= 0 || otx.srAmount <= 0 || otx.rrAmount <= 0 || otx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidFields,
        "Trade failed: invalid required fields (tid=${tx.tid})",
        "Some required trade details are missing or invalid.",
        silent: !debugLogs,
      );
    }

    if (otx.balance <= 0) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidBalance,
        "Trade failed: balance <= 0 (tid=${tx.tid})",
        "This trade cannot be processed because the remaining balance is invalid.",
        silent: !debugLogs,
      );
    }

    return true;
  }

  Future<double> getCapitalBalance(TransactionsModel tx) async {
    final children = await getLeaf(tx);
    final double spent = children.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final double balance = tx.rrAmount - spent;

    return balance;
  }

  Future<void> _deleteLeaves(TransactionsModel tx) async {
    final all = await getAll();
    for (final ttx in all) {
      if (tx.tid == ttx.rid || tx.tid == ttx.pid) {
        if (debugLogs) {
          logln(
            '[DELETE] ${tx.tid}|${tx.pid}|${tx.rid}|${tx.srId}|${tx.srAmount}|${tx.rrId}|${tx.rrAmount}|${tx.balance}|${tx.status}|${tx.closable}|${tx.timestamp}',
          );
        }

        _box.delete(ttx.tid);
      }
    }
  }
}
