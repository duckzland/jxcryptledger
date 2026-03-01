import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesCreate extends TransactionsRulesBase {
  TransactionsRulesCreate(super.tx, super.txRepo, super.silent);

  @override
  Future<bool> validate() async {
    final ptx = await txRepo.get(tx.pid);
    final rtx = await txRepo.get(tx.rid);

    if (tx.tid == '0') {
      throw ValidationException(AppErrorCode.txAddInvalidTid, "Add failed: tid == '0'", "This transaction is invalid.", silent: silent);
    }

    if (tx.pid == '0' && tx.rid != '0') {
      throw ValidationException(
        AppErrorCode.txAddPidZeroRidNotZero,
        "Add failed: pid=0 but rid!=0 (pid=${tx.pid}, rid=${tx.rid})",
        "This transaction is not linked correctly.",
        silent: silent,
      );
    }

    if (tx.rid == '0' && tx.pid != '0') {
      throw ValidationException(
        AppErrorCode.txAddRidZeroPidNotZero,
        "Add failed: rid=0 but pid!=0 (pid=${tx.pid}, rid=${tx.rid})",
        "This transaction is not linked correctly.",
        silent: silent,
      );
    }

    if (tx.rrId <= 0 || tx.srId <= 0 || tx.srAmount <= 0 || tx.rrAmount <= 0 || tx.timestamp <= 0) {
      throw ValidationException(
        AppErrorCode.txAddInvalidFields,
        "Add failed: invalid required fields (tid=${tx.tid})",
        "Some required transaction details are missing or invalid.",
        silent: silent,
      );
    }

    if (tx.srId == tx.rrId) {
      throw ValidationException(
        AppErrorCode.txSourceIdEqualResultId,
        "Update failed: Source Id cannot be the same as ResultId (tid=${tx.tid}, srId=${tx.srId}, rrId=${tx.rrId})",
        "Invalid transaction, same source and target coin.",
        silent: silent,
      );
    }

    if (tx.statusEnum != TransactionStatus.active) {
      throw ValidationException(
        AppErrorCode.txAddStatusNotActive,
        "Add failed: new transaction must be active (status=${tx.statusEnum})",
        "A new transaction must start as active.",
        silent: silent,
      );
    }

    if (tx.isRoot) {
      if (tx.balance != tx.rrAmount) {
        throw ValidationException(
          AppErrorCode.txAddRootBalanceMismatch,
          "Add failed: root balance mismatch (balance=${tx.balance}, rrAmount=${tx.rrAmount})",
          "The transaction balance does not match the expected amount.",
          silent: silent,
        );
      }

      if (tx.closable != true) {
        throw ValidationException(
          AppErrorCode.txAddRootNotClosable,
          "Add failed: root must be closable=true (tid=${tx.tid})",
          "This transaction must be marked as closable.",
          silent: silent,
        );
      }
    }

    if (tx.isLeaf) {
      final targetCloser = await txRepo.getCloseTargetParent(tx);

      if (rtx == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafMissingRoot,
          "Add failed: missing root (rtx == null, rid=${tx.rid})",
          "This transaction is not linked correctly.",
          silent: silent,
        );
      }

      if (ptx == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafMissingParent,
          "Add failed: missing parent (ptx == null, pid=${tx.pid})",
          "This transaction is not linked correctly.",
          silent: silent,
        );
      }

      if (tx.srId != ptx.rrId) {
        throw ValidationException(
          AppErrorCode.txAddLeafSrIdMismatch,
          "Add failed: srId=${tx.srId} does not match parent.rrId=${ptx.rrId}",
          "This transaction does not match the expected account.",
          silent: silent,
        );
      }

      if (tx.srAmount > ptx.balance) {
        throw ValidationException(
          AppErrorCode.txAddLeafAmountExceedsBalance,
          "Add failed: srAmount=${tx.srAmount} exceeds parent.balance=${ptx.balance}",
          "The transaction amount exceeds the available balance.",
          silent: silent,
        );
      }

      if (tx.closable == true && targetCloser == null) {
        throw ValidationException(
          AppErrorCode.txAddLeafClosableNoTarget,
          "Add failed: closable=true but no targetCloser found",
          "This transaction cannot be marked as closable yet.",
          silent: silent,
        );
      }

      if (tx.closable == false && targetCloser != null) {
        throw ValidationException(
          AppErrorCode.txAddLeafNotClosableHasTarget,
          "Add failed: closable=false but targetCloser exists",
          "This transaction must be marked as closable.",
          silent: silent,
        );
      }
    }

    return true;
  }
}
