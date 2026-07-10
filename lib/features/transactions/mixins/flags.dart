import '../controller.dart';
import '../model.dart';

mixin TransactionsMixinsFlags {
  late final TransactionsController txController;
  late List<TransactionsModel> txs;

  Map<String, Map<String, bool>> txsFlags = {};

  Map<String, bool> txFlagCompute(TransactionsModel tx) {
    return {
      'tradable': txController.isTradable(tx),
      'closable': txController.isClosable(tx),
      'deletable': txController.isDeletable(tx),
      'updatable': txController.isUpdatable(tx),
      'refundable': txController.isRefundable(tx),
      'finalizable': txController.isFinalizable(tx),
      'hasLeaf': txController.hasLeaf(tx),
      'hasTradeableLeaf': txController.hasTradeableLeaf(tx),
    };
  }

  bool txFlagPick(TransactionsModel tx, String flag) {
    final flags = txFlagGet(tx);
    if (flags == null) {
      return false;
    }

    if (flags.containsKey(flag)) {
      return flags[flag]!;
    }

    return false;
  }

  Map<String, bool>? txFlagGet(TransactionsModel tx) {
    if (!txsFlags.containsKey(tx.uuid)) {
      txsFlags[tx.uuid] = txFlagCompute(tx);
    }

    if (txsFlags.containsKey(tx.uuid)) {
      return txsFlags[tx.uuid];
    }

    return null;
  }

  void txFlagRebuild() {
    txsFlags.clear();
    for (final tx in txs) {
      txsFlags[tx.uuid] = txFlagCompute(tx);
    }
  }
}
