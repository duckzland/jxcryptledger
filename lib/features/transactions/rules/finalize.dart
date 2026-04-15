import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesFinalize extends TransactionsRulesBase {
  TransactionsRulesFinalize(super.tx, super.txRepo, super.silent, {super.mode = "[TXFINALIZE]"});

  @override
  bool validate() {
    otxCheckActiveOrPartial(AppErrorCode.txUpdateFinalizableRequiresActive, "Transaction must be active for finalization.");

    txCheckLeavesIsNotActive(
      AppErrorCode.txUpdateFinalizableRequiresInactiveLeaves,
      "This transaction cannot be finalized because it has active child transaction.",
    );

    return true;
  }
}
