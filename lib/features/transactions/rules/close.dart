import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesClose extends TransactionsRulesBase {
  TransactionsRulesClose(super.tx, super.txRepo, super.silent, {super.mode = "[TXCLOSE]"});

  @override
  Future<bool> validate() async {
    txCheckIsLeaf(AppErrorCode.txCloseNotLeaf, "This transaction cannot be closed directly.");

    txCheckIsActive(AppErrorCode.txCloseNotActive, "An inactive transaction cannot be closed.");

    await txCheckIsClosable(AppErrorCode.txCloseNoTarget, "This transaction is not ready to be closed yet.");

    return true;
  }
}
