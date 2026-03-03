import '../../../app/exceptions.dart';
import '../model.dart';
import 'base.dart';

class TransactionsRulesDelete extends TransactionsRulesBase {
  TransactionsRulesDelete(super.tx, super.txRepo, super.silent, {super.mode = "[TXDELETE]"});

  @override
  Future<bool> validate() async {
    txCheckIsRoot(AppErrorCode.txDeleteNotRoot, "This transaction cannot be deleted.");

    await txCheckTerminalIsClosed(
      AppErrorCode.txDeleteActiveChildren,
      "This transaction cannot be deleted because related transactions are still in progress.",
    );

    await txCheckLeavesIsNotActive(
      AppErrorCode.txDeleteInactiveLeaves,
      "This transaction cannot be deleted because related transactions are still in progress.",
    );

    return true;
  }
}
