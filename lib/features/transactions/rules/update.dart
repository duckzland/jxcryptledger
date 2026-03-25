import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesUpdate extends TransactionsRulesBase {
  TransactionsRulesUpdate(super.tx, super.txRepo, super.silent, {super.mode = "[TXUPDATE]"});

  @override
  bool validate() {
    otxCheckExists(AppErrorCode.txUpdateNotFound, "This transaction can no longer be found.");

    otxCheckValidRootId(AppErrorCode.txUpdateRootPidRid, "This transaction cannot be changed in that way.");

    otxCheckValidLeaf(AppErrorCode.txUpdateLeafMissingParent, "This transaction is not linked correctly.");

    otxCheckAllowChangeSrOrRrFields(
      AppErrorCode.txUpdateCannotChangeSrRr,
      "This transaction cannot change its accounts or amounts because related transactions depend on it.",
    );

    otxCheckSufficientBalance(
      AppErrorCode.txUpdateParentInsufficientBalance,
      "This transaction cannot change its source amounts because the parent has insufficient balance.",
    );

    final otx = origTx;
    final targetCloser = targetParentCloser;
    final children = leafChildren;
    final hasChildren = children.isNotEmpty;

    if (tx.status != otx!.status) {
      switch (tx.statusEnum) {
        case TransactionStatus.inactive:
          txCheckMustHaveChildren(AppErrorCode.txUpdateInactiveRequiresChildren, "This transaction cannot be marked inactive.");

          otxCheckBalanceIsZero(
            AppErrorCode.txUpdateInactiveRequiresZeroBalance,
            "This transaction still has remaining balance and cannot be marked inactive.",
          );
          break;

        case TransactionStatus.active:
          if (!hasChildren) {
            txCheckHasEnoughBalance(
              AppErrorCode.txUpdateActiveRequiresBalance,
              "This transaction must have a positive balance to remain active.",
            );
          }

          if (hasChildren) {
            txCheckTerminalIsClosed(
              AppErrorCode.txUpdateActiveRequiresChildrenClosed,
              "All related transactions must be completed before this one can be active.",
            );
          }

          break;

        case TransactionStatus.partial:
          txCheckMustHaveChildren(
            AppErrorCode.txUpdatePartialRequiresChildren,
            "This transaction cannot be marked as partially completed.",
          );

          txCheckTerminalIsNotAllClosed(
            AppErrorCode.txUpdatePartialCannotAllClosed,
            "This transaction cannot be marked as partial because all related transactions are already completed.",
          );

          break;

        case TransactionStatus.closed:
          txCheckIsRoot(AppErrorCode.txUpdateClosedRoot, "This transaction cannot be closed directly.");

          txCheckIsClosable(AppErrorCode.txUpdateClosedRequiresTarget, "This transaction is not ready to be closed yet.");
          break;

        case TransactionStatus.unknown:
          break;
      }
    }

    if (tx.closable != otx.closable) {
      switch (tx.closable) {
        case true:
          if (tx.isRoot) {
            txCheckTerminalIsClosed(AppErrorCode.txUpdateClosableRootRequiresClosed, "This transaction cannot be marked as closable yet.");
          }

          if (tx.isLeaf) {
            otxCheckIsActive(
              AppErrorCode.txUpdateClosableLeafRequiresActive,
              "This transaction must be active before it can be marked as closable.",
            );
            txCheckIsClosable(AppErrorCode.txUpdateClosableLeafRequiresTarget, "This transaction cannot be marked as closable yet.");
          }
          break;

        case false:
          if (tx.isRoot) {
            txCheckTerminalIsNotAllClosed(AppErrorCode.txUpdateNotClosableRootAllClosed, "This transaction must remain closable.");
          }
          if (tx.isLeaf && otx.isActive && targetCloser != null) {
            throw ValidationException(
              AppErrorCode.txUpdateNotClosableLeafActiveTarget,
              "$mode leaf cannot be not-closable when active with targetCloser (tid=${tx.tid})",
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
