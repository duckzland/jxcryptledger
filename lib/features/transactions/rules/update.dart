import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesUpdate extends TransactionsRulesBase {
  TransactionsRulesUpdate(super.tx, super.txRepo, super.silent);

  @override
  Future<bool> validate() async {
    final otx = await txRepo.get(tx.tid);
    final ptx = await txRepo.get(tx.pid);
    final rtx = await txRepo.get(tx.rid);

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Update failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot update, same source and target coin.",
        silent: silent,
      );
    }

    if (otx == null) {
      throw ValidationException(
        AppErrorCode.txUpdateNotFound,
        "Update failed: original transaction not found (tid=${tx.tid})",
        "This transaction can no longer be found.",
        silent: silent,
      );
    }

    if (otx.isRoot && (tx.pid != '0' || tx.rid != '0')) {
      throw ValidationException(
        AppErrorCode.txUpdateRootPidRid,
        "Update failed: root cannot change pid/rid (tid=${tx.tid})",
        "This transaction cannot be changed in that way.",
        silent: silent,
      );
    }

    if (otx.isLeaf && (ptx == null || rtx == null)) {
      throw ValidationException(
        AppErrorCode.txUpdateLeafMissingParent,
        "Update failed: leaf missing parent or root (tid=${tx.tid})",
        "This transaction is not linked correctly.",
        silent: silent,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txUpdateInvalidFields,
        "Update failed: invalid required fields (tid=${tx.tid})",
        "Some required transaction details are missing or invalid.",
        silent: silent,
      );
    }

    final leaves = await txRepo.collectTerminalLeaves(tx);
    final targetCloser = await txRepo.getCloseTargetParent(tx);
    final children = await txRepo.getLeaf(tx);

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
          silent: silent,
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
        silent: silent,
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
              silent: silent,
            );
          }
          if (balance > 0) {
            throw ValidationException(
              AppErrorCode.txUpdateInactiveRequiresZeroBalance,
              "Update failed: inactive requires zero balance (tid=${tx.tid})",
              "This transaction still has remaining balance and cannot be marked inactive.",
              silent: silent,
            );
          }
          break;

        case TransactionStatus.active:
          if (!hasChildren && tx.balance <= 0) {
            throw ValidationException(
              AppErrorCode.txUpdateActiveRequiresBalance,
              "Update failed: active requires positive balance (tid=${tx.tid})",
              "This transaction must have a positive balance to remain active.",
              silent: silent,
            );
          }
          if (hasChildren && !allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdateActiveRequiresChildrenClosed,
              "Update failed: active requires all children closed (tid=${tx.tid})",
              "All related transactions must be completed before this one can be active.",
              silent: silent,
            );
          }
          break;

        case TransactionStatus.partial:
          if (!hasChildren) {
            throw ValidationException(
              AppErrorCode.txUpdatePartialRequiresChildren,
              "Update failed: partial requires children (tid=${tx.tid})",
              "This transaction cannot be marked as partially completed.",
              silent: silent,
            );
          }
          if (hasChildren && allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdatePartialCannotAllClosed,
              "Update failed: partial cannot have all children closed (tid=${tx.tid})",
              "This transaction cannot be marked as partial because all related transactions are already completed.",
              silent: silent,
            );
          }
          break;

        case TransactionStatus.closed:
          if (tx.isRoot) {
            throw ValidationException(
              AppErrorCode.txUpdateClosedRoot,
              "Update failed: root cannot be closed (tid=${tx.tid})",
              "This transaction cannot be closed directly.",
              silent: silent,
            );
          }
          if (targetCloser == null) {
            throw ValidationException(
              AppErrorCode.txUpdateClosedRequiresTarget,
              "Update failed: closed requires targetCloser (tid=${tx.tid})",
              "This transaction is not ready to be closed yet.",
              silent: silent,
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
              silent: silent,
            );
          }
          if (tx.isLeaf && !otx.isActive) {
            throw ValidationException(
              AppErrorCode.txUpdateClosableLeafRequiresActive,
              "Update failed: leaf closable requires active (tid=${tx.tid})",
              "This transaction must be active before it can be marked as closable.",
              silent: silent,
            );
          }
          if (tx.isLeaf && targetCloser == null) {
            throw ValidationException(
              AppErrorCode.txUpdateClosableLeafRequiresTarget,
              "Update failed: leaf closable requires targetCloser (tid=${tx.tid})",
              "This transaction cannot be marked as closable yet.",
              silent: silent,
            );
          }
          break;

        case false:
          if (tx.isRoot && allClosed) {
            throw ValidationException(
              AppErrorCode.txUpdateNotClosableRootAllClosed,
              "Update failed: root cannot be not-closable when all children closed (tid=${tx.tid})",
              "This transaction must remain closable.",
              silent: silent,
            );
          }
          if (tx.isLeaf && otx.isActive && targetCloser != null) {
            throw ValidationException(
              AppErrorCode.txUpdateNotClosableLeafActiveTarget,
              "Update failed: leaf cannot be not-closable when active with targetCloser (tid=${tx.tid})",
              "This transaction cannot be marked as not closable.",
              silent: silent,
            );
          }
          break;
      }
    }

    return true;
  }
}
