import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesDelete extends TransactionsRulesBase {
  TransactionsRulesDelete(super.tx, super.txRepo, super.silent);

  @override
  Future<bool> validate() async {
    if (!tx.isRoot) {
      throw ValidationException(
        AppErrorCode.txDeleteNotRoot,
        "Delete failed: transaction is not root (tid=${tx.tid})",
        "This transaction cannot be deleted.",
        silent: silent,
      );
    }

    final terminals = await txRepo.collectTerminalLeaves(tx);
    final allClosed = terminals.isEmpty || terminals.every((leaf) => leaf.statusEnum == TransactionStatus.closed);

    if (!allClosed) {
      throw ValidationException(
        AppErrorCode.txDeleteActiveChildren,
        "Delete failed: active terminal children exist (tid=${tx.tid})",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: silent,
      );
    }

    final leaves = await txRepo.collectAllLeaves(tx);
    final allInactive =
        leaves.isEmpty ||
        leaves.every((leaf) => leaf.statusEnum == TransactionStatus.closed || leaf.statusEnum == TransactionStatus.inactive);

    if (!allInactive) {
      throw ValidationException(
        AppErrorCode.txDeleteInactiveLeaves,
        "Delete failed: some leaves are still active (tid=${tx.tid})",
        "This transaction cannot be deleted because related transactions are still in progress.",
        silent: silent,
      );
    }

    return true;
  }
}
