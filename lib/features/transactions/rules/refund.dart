import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesRefund extends TransactionsRulesBase {
  TransactionsRulesRefund(super.tx, super.txRepo, super.silent, {super.mode = "[TXREFUND]"});

  @override
  bool validate() {
    txCheckIsActive(AppErrorCode.txRefundInactive, "Transaction is not active.");

    txCheckIsLeaf(AppErrorCode.txRefundRootClosed, "This closed root transaction cannot be refunded.");

    txCheckHasEnoughBalance(AppErrorCode.txRefundInsufficientBalance, "Insufficient remaining balance for refund.");

    otxCheckExists(AppErrorCode.txRefundNotFound, "The original transaction can no longer be found.");

    otxCheckValidLeaf(AppErrorCode.txRefundInvalidLinkage, "The transaction is not linked correctly.");

    txCheckMustNotHaveChildren(AppErrorCode.txRefundHasChildren, "This transaction has related child transactions.");

    final ptx = parentTx;

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
