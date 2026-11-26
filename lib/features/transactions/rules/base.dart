import 'package:decimal/decimal.dart';

import '../../../app/exceptions.dart';
import '../../../core/math.dart';
import '../helper.dart';
import '../model.dart';

abstract class TransactionsRulesBase {
  final TransactionsModel tx;
  final Map<String, TransactionsModel> txsMap;
  final Map<String, List<TransactionsModel>>? childrenMap;
  final Map<String, Map<String, TransactionsModel>>? rootMap;
  final bool silent;
  String mode;

  TransactionsRulesBase(this.tx, this.txsMap, this.childrenMap, this.rootMap, this.silent, {this.mode = "[TXERROR]"});

  TransactionsModel? _otxCache;
  TransactionsModel? _ptxCache;
  TransactionsModel? _rtxCache;
  List<TransactionsModel>? _terminalLeavesCache;
  TransactionsModel? _targetCloserCache;
  List<TransactionsModel>? _childrenCache;
  List<TransactionsModel>? _allLeavesCache;
  List<TransactionsModel>? _allRootLeavesCache;

  TransactionsModel? get origTx => _otxCache ??= txsMap[tx.tid];

  TransactionsModel? get parentTx => _ptxCache ??= txsMap[tx.pid];

  TransactionsModel? get rootTx => _rtxCache ??= txsMap[tx.rid];

  List<TransactionsModel> get terminalLeaves =>
      _terminalLeavesCache ??= TransactionsHelper.collectTerminalLeaves(tx, childrenMap: childrenMap, txsMap: txsMap);

  TransactionsModel? get targetParentCloser =>
      _targetCloserCache ??= TransactionsHelper.getCloseTargetParent(tx, txsMap: rootMap?[tx.rid] ?? txsMap);

  List<TransactionsModel> get leafChildren => _childrenCache ??= TransactionsHelper.getLeaf(tx, childrenMap: childrenMap, txsMap: txsMap);

  List<TransactionsModel> get allLeaves =>
      _allLeavesCache ??= TransactionsHelper.collectTerminalLeaves(tx, childrenMap: childrenMap, txsMap: txsMap);

  List<TransactionsModel> get allRootLeaves =>
      _allRootLeavesCache ??= TransactionsHelper.collectRootTreeLeaves(tx, txsMap: rootMap?[tx.tid] ?? txsMap);

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
