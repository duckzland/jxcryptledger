import 'package:decimal/decimal.dart';

import '../../../app/exceptions.dart';
import '../../../core/math.dart';
import '../model.dart';
import '../repository.dart';

abstract class TransactionsRulesBase {
  final TransactionsModel tx;
  final TransactionsRepository txRepo;
  final bool silent;
  final Map<dynamic, TransactionsModel>? overlay;
  String mode;

  TransactionsRulesBase(this.tx, this.txRepo, this.silent, {this.mode = "[TXERROR]", this.overlay});

  TransactionsModel? _otxCache;
  TransactionsModel? _ptxCache;
  TransactionsModel? _rtxCache;
  List<TransactionsModel>? _terminalLeavesCache;
  TransactionsModel? _targetCloserCache;
  List<TransactionsModel>? _childrenCache;
  List<TransactionsModel>? _allLeavesCache;
  List<TransactionsModel>? _allRootLeavesCache;
  Map<dynamic, TransactionsModel>? _overlayMapCache;

  bool get _hasOverlay {
    return overlay != null && overlay!.isNotEmpty;
  }

  Map<dynamic, TransactionsModel> get _overlayMap {
    return _overlayMapCache ??= {...txRepo.getIndexedMap(), ...overlay!};
  }

  TransactionsModel? get origTx {
    if (_otxCache != null) {
      return _otxCache;
    }

    if (!_hasOverlay) {
      _otxCache = txRepo.getIndexedMap()[tx.tid] ?? txRepo.get(tx.tid);
      return _otxCache;
    }

    _otxCache = overlay![tx.tid] ?? txRepo.getIndexedMap()[tx.tid] ?? txRepo.get(tx.tid);
    return _otxCache;
  }

  TransactionsModel? get parentTx {
    if (_ptxCache != null) {
      return _ptxCache;
    }

    if (!_hasOverlay) {
      _ptxCache = txRepo.getIndexedMap()[tx.pid] ?? txRepo.get(tx.pid);
      return _ptxCache;
    }

    _ptxCache = overlay![tx.pid] ?? txRepo.getIndexedMap()[tx.pid] ?? txRepo.get(tx.pid);
    return _ptxCache;
  }

  TransactionsModel? get rootTx {
    if (_rtxCache != null) {
      return _rtxCache;
    }

    if (!_hasOverlay) {
      _rtxCache = txRepo.getIndexedMap()[tx.rid] ?? txRepo.get(tx.rid);
      return _rtxCache;
    }

    _rtxCache = overlay![tx.rid] ?? txRepo.getIndexedMap()[tx.rid] ?? txRepo.get(tx.rid);
    return _rtxCache;
  }

  List<TransactionsModel> get terminalLeaves {
    if (_terminalLeavesCache != null) {
      return _terminalLeavesCache!;
    }

    if (!_hasOverlay) {
      _terminalLeavesCache = txRepo.collectTerminalLeaves(tx);
      return _terminalLeavesCache!;
    }

    final byTid = _overlayMap;
    final List<TransactionsModel> result = [];

    void collect(TransactionsModel current) {
      final children = byTid.values.where((item) => item.pid == current.tid).toList();
      if (children.isEmpty) {
        if (current.tid != tx.tid) {
          result.add(current);
        }
        return;
      }

      for (final child in children) {
        collect(child);
      }
    }

    collect(tx);
    _terminalLeavesCache = result;
    return _terminalLeavesCache!;
  }

  TransactionsModel? get targetParentCloser {
    if (_targetCloserCache != null) {
      return _targetCloserCache;
    }

    if (!_hasOverlay) {
      _targetCloserCache = txRepo.getCloseTargetParent(tx);
      return _targetCloserCache;
    }

    if (tx.isRoot) {
      return null;
    }

    final byTid = _overlayMap;
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
      final root = byTid[tx.rid];
      if (root != null && root.isRoot && root.rrId == tx.rrId) {
        parent = root;
      }
    }

    _targetCloserCache = parent;
    return _targetCloserCache;
  }

  List<TransactionsModel> get leafChildren {
    if (_childrenCache != null) {
      return _childrenCache!;
    }

    if (!_hasOverlay) {
      _childrenCache = txRepo.getLeaf(tx);
      return _childrenCache!;
    }

    final byTid = _overlayMap;
    _childrenCache = byTid.values.where((item) => item.pid == tx.tid).toList();
    return _childrenCache!;
  }

  List<TransactionsModel> get allLeaves {
    if (_allLeavesCache != null) {
      return _allLeavesCache!;
    }

    if (!_hasOverlay) {
      _allLeavesCache = txRepo.collectDirectLeaves(tx);
      return _allLeavesCache!;
    }

    final byTid = _overlayMap;
    _allLeavesCache = byTid.values.where((item) => item.pid == tx.tid).toList();
    return _allLeavesCache!;
  }

  List<TransactionsModel> get allRootLeaves {
    if (_allRootLeavesCache != null) {
      return _allRootLeavesCache!;
    }

    if (!_hasOverlay) {
      _allRootLeavesCache = txRepo.collectRootTreeLeaves(tx);
      return _allRootLeavesCache!;
    }

    final byTid = _overlayMap;
    _allRootLeavesCache = byTid.values.where((item) => item.rid == tx.tid).toList();
    return _allRootLeavesCache!;
  }

  void txCheckIsRoot(int code, String message) {
    if (!tx.isRoot) {
      throw ValidationException(code, "$mode transaction is not root (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckIsLeaf(int code, String message) {
    if (!tx.isLeaf) {
      throw ValidationException(code, "$mode transaction is not leaf (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckIsActive(int code, String message) {
    if (!tx.isActive) {
      throw ValidationException(code, "$mode transaction is not active (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckHasEnoughBalance(int code, String message) {
    if (tx.balance <= Decimal.zero) {
      throw ValidationException(code, "$mode transaction has negative balance (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckLeafHasValidRoot(int code, String message) {
    final rtx = rootTx;

    if (rtx == null) {
      throw ValidationException(code, "$mode missing root (rtx == null, rid=${tx.rid})", message, silent: silent);
    }
  }

  void txCheckLeafHasValidParent(int code, String message) {
    final ptx = parentTx;

    if (ptx == null) {
      throw ValidationException(code, "$mode missing parent (ptx == null, pid=${tx.pid})", message, silent: silent);
    }
  }

  void txCheckTerminalIsClosed(int code, String message) {
    final terminals = terminalLeaves;
    final allClosed =
        terminals.isEmpty ||
        terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.finalized);

    if (!allClosed) {
      throw ValidationException(code, "$mode active terminal is not all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckTerminalIsNotAllClosed(int code, String message) {
    final terminals = terminalLeaves;
    final allClosed =
        terminals.isEmpty ||
        terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.finalized);

    if (allClosed) {
      throw ValidationException(code, "$mode active terminal is all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckLeavesIsNotActive(int code, String message) {
    final leaves = tx.isRoot ? allRootLeaves : allLeaves;
    final allInactive =
        leaves.isEmpty ||
        leaves.every(
          (leaf) =>
              leaf.statusEnum == TransactionStatus.closed ||
              leaf.statusEnum == TransactionStatus.inactive ||
              leaf.statusEnum == TransactionStatus.finalized,
        );

    if (!allInactive) {
      throw ValidationException(code, "$mode some leaves are still active (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckIsClosable(int code, String message) {
    final targetCloser = targetParentCloser;
    if (targetCloser == null) {
      throw ValidationException(code, "$mode no targetCloser found (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckMustHaveChildren(int code, String message) {
    final childList = leafChildren;
    final hasChildren = childList.isNotEmpty;

    if (!hasChildren) {
      throw ValidationException(code, "$mode requires child transaction(tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckMustNotHaveChildren(int code, String message) {
    final childList = leafChildren;
    final hasChildren = childList.isNotEmpty;

    if (hasChildren) {
      throw ValidationException(code, "$mode must not have any children (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckExists(int code, String message) {
    final otx = origTx;

    if (otx == null) {
      throw ValidationException(code, "$mode original transaction not found (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckValidRootId(int code, String message) {
    final TransactionsModel? otx = origTx;

    if (otx != null && otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      throw ValidationException(code, "$mode root cannot change pid/rid (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckIsActive(int code, String message) {
    final TransactionsModel? otx = origTx;

    if (otx != null && !otx.isActive) {
      throw ValidationException(code, "$mode leaf requires active (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckValidLeaf(int code, String message) {
    final TransactionsModel? otx = origTx;
    final TransactionsModel? ptx = parentTx;
    final TransactionsModel? rtx = rootTx;

    if (otx != null && otx.isLeaf && (ptx == null || rtx == null)) {
      throw ValidationException(code, "$mode leaf missing parent or root (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckSufficientBalance(int code, String message) {
    final TransactionsModel? otx = origTx;
    final TransactionsModel? ptx = parentTx;

    if (otx != null &&
        otx.isLeaf &&
        ptx != null &&
        otx.srAmount != tx.srAmount &&
        otx.srAmount < tx.srAmount &&
        ptx.balance < Math.subtract(tx.srAmount, otx.srAmount)) {
      throw ValidationException(
        AppErrorCode.txUpdateParentInsufficientBalance,
        "$mode parent has insufficient balance (tid=${tx.tid})",
        message,
        silent: silent,
      );
    }
  }

  void otxCheckAllowChangeSrOrRrFields(int code, String message) {
    final TransactionsModel? otx = origTx;
    final childList = leafChildren;

    final hasChildren = childList.isNotEmpty;

    if (otx != null) {
      if (tx.rrId != otx.rrId || tx.rrAmount != otx.rrAmount || tx.srId != otx.srId || tx.srAmount != otx.srAmount) {
        if (hasChildren) {
          throw ValidationException(code, "$mode cannot change SR/RR fields when children exist (tid=${tx.tid})", message, silent: silent);
        }
      }
    }
  }

  void otxCheckActiveOrPartial(int code, String message) {
    final TransactionsModel? otx = origTx;

    if (otx != null && !otx.isActive && !otx.isPartial) {
      throw ValidationException(code, "$mode transaction not active or partial (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckPositiveBalance(int code, String message) {
    final TransactionsModel? otx = origTx;
    if (otx != null && otx.balance <= Decimal.zero) {
      throw ValidationException(code, "$mode balance <= 0 (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckBalanceIsZero(int code, String message) {
    final TransactionsModel? otx = origTx;
    final childList = leafChildren;
    final spent = childList.fold<Decimal>(Decimal.zero, (sum, leaf) => Math.add(sum, leaf.srAmount));
    final balance = otx == null ? Decimal.fromInt(-99999) : Math.subtract(otx.rrAmount, spent);

    if (balance > Decimal.zero) {
      throw ValidationException(
        AppErrorCode.txUpdateInactiveRequiresZeroBalance,
        "$mode balance is not zero. (tid=${tx.tid})",
        message,
        silent: silent,
      );
    }
  }

  bool validate();
}
