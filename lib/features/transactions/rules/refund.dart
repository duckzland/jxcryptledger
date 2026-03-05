import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesRefund extends TransactionsRulesBase {
  TransactionsRulesRefund(super.tx, super.txRepo, super.silent, {super.mode = "[TXREFUND]"});

  @override
  Future<bool> validate() async {
    txCheckValidTid(AppErrorCode.txRefundInvalidId, "Invalid transaction ID (tid=${tx.tid}).");

    txCheckValidFields(AppErrorCode.txRefundInvalidFields, "Required transaction fields are missing or invalid.");

    txCheckIsActive(AppErrorCode.txRefundInactive, "Transaction is not active.");

    txCheckSrIdMustNotEqualRrId(AppErrorCode.txRefundSourceEqualsTarget, "Source and target coin cannot be the same.");

    txCheckIsLeaf(AppErrorCode.txRefundRootClosed, "This closed root transaction cannot be refunded.");

    txCheckHasEnoughBalance(AppErrorCode.txRefundInsufficientBalance, "Insufficient remaining balance for refund.");

    await otxCheckExists(AppErrorCode.txRefundNotFound, "The original transaction can no longer be found.");

    await otxCheckValidLeaf(AppErrorCode.txRefundInvalidLinkage, "The transaction is not linked correctly.");

    await txCheckMustNotHaveChildren(AppErrorCode.txRefundHasChildren, "This transaction has related child transactions.");

    final ptx = await parentTx;

    if (ptx!.rrId != tx.srId) {
      throw ValidationException(
        AppErrorCode.txRefundParentMismatch,
        "$mode parent transaction mismatch (tid=${tx.tid}).",
        "Parent transaction does not match expected source coin.",
        silent: silent,
      );
    }

    return true;
  }
}
