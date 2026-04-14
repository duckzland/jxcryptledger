import '../../../core/math.dart';
import '../model.dart';
import '../repository.dart';
import '../../../app/exceptions.dart';

abstract class TransactionsRulesBase {
  final TransactionsModel tx;
  final TransactionsRepository txRepo;
  final bool silent;
  String mode;

  TransactionsRulesBase(this.tx, this.txRepo, this.silent, {this.mode = "[TXERROR]"});

  TransactionsModel? _otxCache;
  TransactionsModel? _ptxCache;
  TransactionsModel? _rtxCache;
  List<TransactionsModel>? _terminalLeavesCache;
  TransactionsModel? _targetCloserCache;
  List<TransactionsModel>? _childrenCache;
  List<TransactionsModel>? _allLeavesCache;
  List<TransactionsModel>? _allRootLeavesCache;

  TransactionsModel? get origTx => _otxCache ??= txRepo.get(tx.tid);
  TransactionsModel? get parentTx => _ptxCache ??= txRepo.get(tx.pid);
  TransactionsModel? get rootTx => _rtxCache ??= txRepo.get(tx.rid);
  List<TransactionsModel> get terminalLeaves => _terminalLeavesCache ??= txRepo.collectTerminalLeaves(tx);
  TransactionsModel? get targetParentCloser => _targetCloserCache ??= txRepo.getCloseTargetParent(tx);
  List<TransactionsModel> get leafChildren => _childrenCache ??= txRepo.getLeaf(tx);
  List<TransactionsModel> get allLeaves => _allLeavesCache ??= txRepo.collectDirectLeaves(tx);
  List<TransactionsModel> get allRootLeaves => _allRootLeavesCache ??= txRepo.collectRootTreeLeaves(tx);

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
    if (tx.balance <= 0) {
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
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      throw ValidationException(code, "$mode active terminal is not all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckTerminalIsNotAllClosed(int code, String message) {
    final terminals = terminalLeaves;
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (allClosed) {
      throw ValidationException(code, "$mode active terminal is all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  void txCheckLeavesIsNotActive(int code, String message) {
    final leaves = tx.isRoot ? allRootLeaves : allLeaves;
    final allInactive =
        leaves.isEmpty ||
        leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.inactive);

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
      throw ValidationException(code, "$mode leaf closable requires active (tid=${tx.tid})", message, silent: silent);
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
    if (otx != null && otx.balance <= 0) {
      throw ValidationException(code, "$mode balance <= 0 (tid=${tx.tid})", message, silent: silent);
    }
  }

  void otxCheckBalanceIsZero(int code, String message) {
    final TransactionsModel? otx = origTx;
    final childList = leafChildren;
    final spent = childList.fold<double>(0.0, (sum, leaf) => Math.add(sum, leaf.srAmount));
    final balance = otx == null ? -99999 : Math.subtract(otx.rrAmount, spent);

    if (balance > 0) {
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
