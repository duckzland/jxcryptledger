import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesUpdate extends TransactionsRulesBase {
  TransactionsRulesUpdate(super.tx, super.txRepo, super.silent, {super.mode = "[TXUPDATE]"});

  @override
  Future<bool> validate() async {
    txCheckValidTid(AppErrorCode.txTradeInvalidId, "Cannot update, Invalid ID (tid=${tx.tid})");

    txCheckValidFields(AppErrorCode.txUpdateInvalidFields, "Some required transaction details are missing or invalid.");

    txCheckSrIdMustNotEqualRrId(AppErrorCode.txSourceIdEqualResultId, "Cannot update, same source and target coin.");

    await otxCheckExists(AppErrorCode.txUpdateNotFound, "This transaction can no longer be found.");

    await otxCheckValidRootId(AppErrorCode.txUpdateRootPidRid, "This transaction cannot be changed in that way.");

    await otxCheckValidLeaf(AppErrorCode.txUpdateLeafMissingParent, "This transaction is not linked correctly.");

    await otxCheckAllowChangeSrOrRrFields(
      AppErrorCode.txUpdateCannotChangeSrRr,
      "This transaction cannot change its accounts or amounts because related transactions depend on it.",
    );

    await otxCheckSufficientBalance(
      AppErrorCode.txUpdateParentInsufficientBalance,
      "This transaction cannot change its source amounts because the parent has insufficient balance.",
    );

    final otx = await origTx;
    final targetCloser = await targetParentCloser;
    final children = await leafChildren;
    final hasChildren = children.isNotEmpty;

    if (tx.status != otx!.status) {
      switch (tx.statusEnum) {
        case TransactionStatus.inactive:
          await txCheckMustHaveChildren(AppErrorCode.txUpdateInactiveRequiresChildren, "This transaction cannot be marked inactive.");

          await otxCheckBalanceIsZero(
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
            await txCheckTerminalIsClosed(
              AppErrorCode.txUpdateActiveRequiresChildrenClosed,
              "All related transactions must be completed before this one can be active.",
            );
          }

          break;

        case TransactionStatus.partial:
          await txCheckMustHaveChildren(
            AppErrorCode.txUpdatePartialRequiresChildren,
            "This transaction cannot be marked as partially completed.",
          );

          await txCheckTerminalIsNotAllClosed(
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
            await txCheckTerminalIsClosed(
              AppErrorCode.txUpdateClosableRootRequiresClosed,
              "This transaction cannot be marked as closable yet.",
            );
          }

          if (tx.isLeaf) {
            await otxCheckIsActive(
              AppErrorCode.txUpdateClosableLeafRequiresActive,
              "This transaction must be active before it can be marked as closable.",
            );
            await txCheckIsClosable(AppErrorCode.txUpdateClosableLeafRequiresTarget, "This transaction cannot be marked as closable yet.");
          }
          break;

        case false:
          if (tx.isRoot) {
            await txCheckTerminalIsNotAllClosed(AppErrorCode.txUpdateNotClosableRootAllClosed, "This transaction must remain closable.");
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
