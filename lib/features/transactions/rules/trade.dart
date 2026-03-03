import '../../../app/exceptions.dart';
import 'base.dart';

class TransactionsRulesTrade extends TransactionsRulesBase {
  TransactionsRulesTrade(super.tx, super.txRepo, super.silent, {super.mode = "[TXTRADE]"});

  @override
  Future<bool> validate() async {
    txCheckValidTid(AppErrorCode.txTradeInvalidId, "This trade cannot be processed because its ID is invalid.");

    txCheckValidFields(AppErrorCode.txTradeInvalidFields, "Some required trade details are missing or invalid.");

    txCheckSrIdMustNotEqualRrId(AppErrorCode.txSourceIdEqualResultId, "Cannot trade for same source and target coin.");

    await otxCheckExists(AppErrorCode.txTradeNotFound, "This trade cannot be processed because the original transaction was not found.");

    await otxCheckValidLeaf(AppErrorCode.txTradeMissingParent, "Invalid transaction cannot be traded.");

    await otxCheckActiveOrPartial(
      AppErrorCode.txTradeInvalidState,
      "This trade cannot be processed because the original transaction is not in a valid state.",
    );

    await otxCheckPositiveBalance(
      AppErrorCode.txTradeInvalidBalance,
      "This trade cannot be processed because the remaining balance is invalid.",
    );

    return true;
  }
}
