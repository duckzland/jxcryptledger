import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesDelete extends TransactionsRulesBase {
  TransactionsRulesDelete(super.tx, super.txRepo, super.silent, {super.mode = "[TXDELETE]"});

  @override
  bool validate() {
    txCheckIsRoot(AppErrorCode.txDeleteNotRoot, "This transaction cannot be deleted.");

    txCheckTerminalIsClosed(
      AppErrorCode.txDeleteActiveChildren,
      "This transaction cannot be deleted because related transactions are still in progress.",
    );

    txCheckLeavesIsNotActive(
      AppErrorCode.txDeleteInactiveLeaves,
      "This transaction cannot be deleted because related transactions are still in progress.",
    );

    return true;
  }
}
