import '../../../core/abstracts/batch/action.dart';
import '../model.dart';

sealed class TransactionsBatchAction extends CoreBatchAction<TransactionsModel> {
  TransactionsBatchAction(super.item, {super.tag});
  TransactionsModel get tx => item;
}

class TransactionsCloseAction extends TransactionsBatchAction {
  TransactionsCloseAction(super.item, {super.tag});
}

class TransactionsAddAction extends TransactionsBatchAction {
  TransactionsAddAction(super.item, {super.tag});
}

class TransactionsRemoveAction extends TransactionsBatchAction {
  TransactionsRemoveAction(super.item, {super.tag});
}

class TransactionsRefundAction extends TransactionsBatchAction {
  TransactionsRefundAction(super.item, {super.tag});
}

class TransactionsFinalizeAction extends TransactionsBatchAction {
  TransactionsFinalizeAction(super.item, {super.tag});
}

class TransactionsUpdateAction extends TransactionsBatchAction {
  TransactionsUpdateAction(super.item, {super.tag});
}
