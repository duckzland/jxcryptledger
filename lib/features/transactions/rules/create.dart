import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesCreate extends TransactionsRulesBase {
  TransactionsRulesCreate(super.tx, super.txRepo, super.silent, {super.mode = "[TXCREATE]"});

  @override
  Future<bool> validate() async {
    txCheckValidTid(AppErrorCode.txAddInvalidTid, "This transaction is invalid.");

    txCheckValidRootPid(AppErrorCode.txAddPidZeroRidNotZero, "This transaction is not linked correctly.");

    txCheckValidRootRid(AppErrorCode.txAddRidZeroPidNotZero, "This transaction is not linked correctly.");

    txCheckValidFields(AppErrorCode.txAddInvalidFields, "Some required transaction details are missing or invalid.");

    txCheckSrIdMustNotEqualRrId(AppErrorCode.txSourceIdEqualResultId, "Invalid transaction, same source and target coin.");

    txCheckIsActive(AppErrorCode.txAddStatusNotActive, "A new transaction must start as active.");

    if (tx.isRoot) {
      if (tx.balance != tx.rrAmount) {
        throw ValidationException(
          AppErrorCode.txAddRootBalanceMismatch,
          "$mode root balance mismatch (balance=${tx.balance}, rrAmount=${tx.rrAmount})",
          "The transaction balance does not match the expected amount.",
          silent: silent,
        );
      }

      if (tx.closable != true) {
        throw ValidationException(
          AppErrorCode.txAddRootNotClosable,
          "$mode root must be closable=true (tid=${tx.tid})",
          "This transaction must be marked as closable.",
          silent: silent,
        );
      }
    }

    if (tx.isLeaf) {
      final targetCloser = await targetParentCloser;
      final ptx = await parentTx;

      await txCheckLeafHasValidRoot(AppErrorCode.txAddLeafMissingRoot, "This transaction is not linked correctly.");

      await txCheckLeafHasValidParent(AppErrorCode.txAddLeafMissingParent, "This transaction is not linked correctly.");

      if (tx.srId != ptx!.rrId) {
        throw ValidationException(
          AppErrorCode.txAddLeafSrIdMismatch,
          "$mode srId=${tx.srId} does not match parent.rrId=${ptx.rrId}",
          "This transaction does not match the expected account.",
          silent: silent,
        );
      }

      if (tx.srAmount > ptx.balance) {
        throw ValidationException(
          AppErrorCode.txAddLeafAmountExceedsBalance,
          "$mode srAmount=${tx.srAmount} exceeds parent.balance=${ptx.balance}",
          "The transaction amount exceeds the available balance.",
          silent: silent,
        );
      }

      if (tx.closable == true) {
        txCheckIsClosable(AppErrorCode.txAddLeafClosableNoTarget, "This transaction cannot be marked as closable yet.");
      }

      if (tx.closable == false && targetCloser != null) {
        throw ValidationException(
          AppErrorCode.txAddLeafNotClosableHasTarget,
          "$mode closable=false but targetCloser exists",
          "This transaction must be marked as closable.",
          silent: silent,
        );
      }
    }

    return true;
  }
}
