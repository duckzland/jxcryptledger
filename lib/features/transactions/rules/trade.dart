import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesTrade extends TransactionsRulesBase {
  TransactionsRulesTrade(super.tx, super.txRepo, super.silent);

  @override
  Future<bool> validate() async {
    if (tx.tid == '0') {
      throw ValidationException(
        AppErrorCode.txTradeInvalidId,
        "Trade failed: invalid tid='0'",
        "This trade cannot be processed because its ID is invalid.",
        silent: silent,
      );
    }

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Trade failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Cannot trade for same source and target coin.",
        silent: silent,
      );
    }

    final otx = await txRepo.get(tx.tid);

    if (otx == null) {
      throw ValidationException(
        AppErrorCode.txTradeNotFound,
        "Trade failed: original transaction not found (tid=${tx.tid})",
        "This trade cannot be processed because the original transaction was not found.",
        silent: silent,
      );
    }

    if (!otx.isRoot) {
      final ptx = await txRepo.get(tx.pid);
      final rtx = await txRepo.get(tx.rid);

      if (ptx == null || rtx == null) {
        throw ValidationException(
          AppErrorCode.txTradeMissingParent,
          "Trade failed: missing parent or root (tid=${tx.tid})",
          "Invalid transaction cannot be traded.",
          silent: silent,
        );
      }
    }

    if (!otx.isActive && !otx.isPartial) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidState,
        "Trade failed: transaction not active or partial (tid=${tx.tid})",
        "This trade cannot be processed because the original transaction is not in a valid state.",
        silent: silent,
      );
    }

    if (otx.rrId <= 0 || otx.srId <= 0 || otx.srAmount <= 0 || otx.rrAmount <= 0 || otx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidFields,
        "Trade failed: invalid required fields (tid=${tx.tid})",
        "Some required trade details are missing or invalid.",
        silent: silent,
      );
    }

    if (otx.balance <= 0) {
      throw ValidationException(
        AppErrorCode.txTradeInvalidBalance,
        "Trade failed: balance <= 0 (tid=${tx.tid})",
        "This trade cannot be processed because the remaining balance is invalid.",
        silent: silent,
      );
    }

    return true;
  }
}
