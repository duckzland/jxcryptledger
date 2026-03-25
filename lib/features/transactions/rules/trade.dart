import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesTrade extends TransactionsRulesBase {
  TransactionsRulesTrade(super.tx, super.txRepo, super.silent, {super.mode = "[TXTRADE]"});

  @override
  // We want the parent not the new trade tx!
  bool validate() {
    otxCheckExists(AppErrorCode.txTradeNotFound, "This trade cannot be processed because the original transaction was not found.");

    otxCheckValidLeaf(AppErrorCode.txTradeMissingParent, "Invalid transaction cannot be traded.");

    otxCheckActiveOrPartial(
      AppErrorCode.txTradeInvalidState,
      "This trade cannot be processed because the original transaction is not in a valid state.",
    );

    otxCheckPositiveBalance(AppErrorCode.txTradeInvalidBalance, "This trade cannot be processed because the remaining balance is invalid.");

    return true;
  }
}
