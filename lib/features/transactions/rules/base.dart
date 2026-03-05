import '../model.dart';
import '../repository.dart';
import '../../../app/exceptions.dart';

abstract class TransactionsRulesBase {
  final TransactionsModel tx;
  final TransactionsRepository txRepo;
  final bool silent;
  String mode;

  TransactionsRulesBase(this.tx, this.txRepo, this.silent, {this.mode = "[TXERROR]"});

  Future<TransactionsModel?>? _otxCache;
  Future<TransactionsModel?>? _ptxCache;
  Future<TransactionsModel?>? _rtxCache;
  Future<List<TransactionsModel>>? _terminalLeavesCache;
  Future<TransactionsModel?>? _targetCloserCache;
  Future<List<TransactionsModel>>? _childrenCache;
  Future<List<TransactionsModel>>? _allLeavesCache;
  Future<List<TransactionsModel>>? _allRootLeavesCache;

  Future<TransactionsModel?> get origTx async => _otxCache ??= txRepo.get(tx.tid);
  Future<TransactionsModel?> get parentTx async => _ptxCache ??= txRepo.get(tx.pid);
  Future<TransactionsModel?> get rootTx async => _rtxCache ??= txRepo.get(tx.rid);
  Future<List<TransactionsModel>> get terminalLeaves async => _terminalLeavesCache ??= txRepo.collectTerminalLeaves(tx);
  Future<TransactionsModel?> get targetParentCloser async => _targetCloserCache ??= txRepo.getCloseTargetParent(tx);
  Future<List<TransactionsModel>> get leafChildren async => _childrenCache ??= txRepo.getLeaf(tx);
  Future<List<TransactionsModel>> get allLeaves async => _allLeavesCache ??= txRepo.collectAllLeaves(tx);
  Future<List<TransactionsModel>> get allRootLeaves async => _allRootLeavesCache ??= txRepo.collectAllRootLeaves(tx);

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

  Future<void> txCheckLeafHasValidRoot(int code, String message) async {
    final rtx = await rootTx;

    if (rtx == null) {
      throw ValidationException(code, "$mode missing root (rtx == null, rid=${tx.rid})", message, silent: silent);
    }
  }

  Future<void> txCheckLeafHasValidParent(int code, String message) async {
    final ptx = await parentTx;

    if (ptx == null) {
      throw ValidationException(code, "$mode missing parent (ptx == null, pid=${tx.pid})", message, silent: silent);
    }
  }

  Future<void> txCheckTerminalIsClosed(int code, String message) async {
    final terminals = await terminalLeaves;
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      throw ValidationException(code, "$mode active terminal is not all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> txCheckTerminalIsNotAllClosed(int code, String message) async {
    final terminals = await terminalLeaves;
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (allClosed) {
      throw ValidationException(code, "$mode active terminal is all closed (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> txCheckLeavesIsNotActive(int code, String message) async {
    final leaves = tx.isRoot ? await allRootLeaves : await allLeaves;
    final allInactive =
        leaves.isEmpty ||
        leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.inactive);

    if (!allInactive) {
      throw ValidationException(code, "$mode some leaves are still active (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> txCheckIsClosable(int code, String message) async {
    final targetCloser = await targetParentCloser;
    if (targetCloser == null) {
      throw ValidationException(code, "$mode no targetCloser found (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> txCheckMustHaveChildren(int code, String message) async {
    final childList = await leafChildren;
    final hasChildren = childList.isNotEmpty;

    if (!hasChildren) {
      throw ValidationException(code, "$mode requires child transaction(tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> txCheckMustNotHaveChildren(int code, String message) async {
    final childList = await leafChildren;
    final hasChildren = childList.isNotEmpty;

    if (hasChildren) {
      throw ValidationException(code, "$mode must not have any children (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckExists(int code, String message) async {
    final otx = await origTx;

    if (otx == null) {
      throw ValidationException(code, "$mode original transaction not found (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckValidRootId(int code, String message) async {
    final TransactionsModel? otx = await origTx;

    if (otx != null && otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      throw ValidationException(code, "$mode root cannot change pid/rid (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckIsActive(int code, String message) async {
    final TransactionsModel? otx = await origTx;

    if (otx != null && !otx.isActive) {
      throw ValidationException(code, "$mode leaf closable requires active (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckValidLeaf(int code, String message) async {
    final TransactionsModel? otx = await origTx;
    final TransactionsModel? ptx = await parentTx;
    final TransactionsModel? rtx = await rootTx;

    if (otx != null && otx.isLeaf && (ptx == null || rtx == null)) {
      throw ValidationException(code, "$mode leaf missing parent or root (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckSufficientBalance(int code, String message) async {
    final TransactionsModel? otx = await origTx;
    final TransactionsModel? ptx = await parentTx;

    if (otx != null &&
        otx.isLeaf &&
        ptx != null &&
        otx.srAmount != tx.srAmount &&
        otx.srAmount < tx.srAmount &&
        ptx.balance < (tx.srAmount - otx.srAmount)) {
      throw ValidationException(
        AppErrorCode.txUpdateParentInsufficientBalance,
        "$mode parent has insufficient balance (tid=${tx.tid})",
        message,
        silent: silent,
      );
    }
  }

  Future<void> otxCheckAllowChangeSrOrRrFields(int code, String message) async {
    final TransactionsModel? otx = await origTx;
    final childList = await leafChildren;

    final hasChildren = childList.isNotEmpty;

    if (otx != null) {
      if (tx.rrId != otx.rrId || tx.rrAmount != otx.rrAmount || tx.srId != otx.srId || tx.srAmount != otx.srAmount) {
        if (hasChildren) {
          throw ValidationException(code, "$mode cannot change SR/RR fields when children exist (tid=${tx.tid})", message, silent: silent);
        }
      }
    }
  }

  Future<void> otxCheckActiveOrPartial(int code, String message) async {
    final TransactionsModel? otx = await origTx;

    if (otx != null && !otx.isActive && !otx.isPartial) {
      throw ValidationException(code, "$mode transaction not active or partial (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckPositiveBalance(int code, String message) async {
    final TransactionsModel? otx = await origTx;
    if (otx != null && otx.balance <= 0) {
      throw ValidationException(code, "$mode balance <= 0 (tid=${tx.tid})", message, silent: silent);
    }
  }

  Future<void> otxCheckBalanceIsZero(int code, String message) async {
    final TransactionsModel? otx = await origTx;
    final childList = await leafChildren;
    final spent = childList.fold<double>(0.0, (sum, leaf) => sum + leaf.srAmount);
    final balance = otx == null ? -99999 : otx.rrAmount - spent;

    if (balance > 0) {
      throw ValidationException(
        AppErrorCode.txUpdateInactiveRequiresZeroBalance,
        "$mode balance is not zero. (tid=${tx.tid})",
        message,
        silent: silent,
      );
    }
  }

  Future<bool> validate();
}
