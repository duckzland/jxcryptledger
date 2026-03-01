import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesClose extends TransactionsRulesBase {
  TransactionsRulesClose(super.tx, super.txRepo, super.silent);

  @override
  Future<bool> validate() async {
    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Close failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot close, same source and target coin.",
        silent: silent,
      );
    }

    if (tx.isRoot) {
      throw ValidationException(
        AppErrorCode.txCloseRoot,
        "Close failed: root cannot be closed (tid=${tx.tid})",
        "This transaction cannot be closed directly.",
        silent: silent,
      );
    }

    if (!tx.isActive) {
      throw ValidationException(
        AppErrorCode.txCloseNotActive,
        "Close failed: transaction is not active (tid=${tx.tid})",
        "An inactive transaction cannot be closed.",
        silent: silent,
      );
    }

    final targetCloser = await txRepo.getCloseTargetParent(tx);

    if (targetCloser == null) {
      throw ValidationException(
        AppErrorCode.txCloseNoTarget,
        "Close failed: no targetCloser found (tid=${tx.tid})",
        "This transaction is not ready to be closed yet.",
        silent: silent,
      );
    }

    return true;
  }
}
