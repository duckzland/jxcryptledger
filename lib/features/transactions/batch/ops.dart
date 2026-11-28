import '../../../core/abstracts/batch/ops.dart';
import '../model.dart';
import 'action.dart';

class TransactionsBatchOps extends CoreBatchOps<TransactionsModel, TransactionsBatchAction> {
  void close(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsCloseAction(tx, tag: tag));
  void add(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsAddAction(tx, tag: tag));
  void remove(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsRemoveAction(tx, tag: tag));
  void refund(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsRefundAction(tx, tag: tag));
  void finalize(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsFinalizeAction(tx, tag: tag));
  void update(TransactionsModel tx, {Object? tag}) => actions.add(TransactionsUpdateAction(tx, tag: tag));
}
