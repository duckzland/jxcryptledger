import '../controller.dart';
import '../model.dart';

enum TransactionsFlagsType { tradable, closable, deletable, updatable, refundable, finalizable, hasLeaf, hasTradeableLeaf }

mixin TransactionsMixinsFlags {
  late final TransactionsController txController;
  late List<TransactionsModel> txs;
  late Map<String, Map<TransactionsFlagsType, bool>> fxs;

  bool fxsIsTradable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.tradable);
  bool fxsIsClosable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.closable);
  bool fxsIsDeletable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.deletable);
  bool fxsIsUpdatable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.updatable);
  bool fxsIsRefundable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.refundable);
  bool fxsIsFinalizable(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.finalizable);
  bool fxsHasLeaf(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.hasLeaf);
  bool fxsHasTradeableLeaf(TransactionsModel tx) => _pick(tx, TransactionsFlagsType.hasTradeableLeaf);

  void fxsRebuild() {
    fxs.clear();
    for (final tx in txs) {
      fxs[tx.uuid] = _compute(tx);
    }
  }

  Map<TransactionsFlagsType, bool> _compute(TransactionsModel tx) {
    return {
      TransactionsFlagsType.tradable: txController.isTradable(tx),
      TransactionsFlagsType.closable: txController.isClosable(tx),
      TransactionsFlagsType.deletable: txController.isDeletable(tx),
      TransactionsFlagsType.updatable: txController.isUpdatable(tx),
      TransactionsFlagsType.refundable: txController.isRefundable(tx),
      TransactionsFlagsType.finalizable: txController.isFinalizable(tx),
      TransactionsFlagsType.hasLeaf: txController.hasLeaf(tx),
      TransactionsFlagsType.hasTradeableLeaf: txController.hasTradeableLeaf(tx),
    };
  }

  bool _pick(TransactionsModel tx, TransactionsFlagsType flag) {
    final flags = _get(tx);
    if (flags == null) return false;
    return flags[flag] ?? false;
  }

  Map<TransactionsFlagsType, bool>? _get(TransactionsModel tx) {
    if (!fxs.containsKey(tx.uuid)) {
      fxs[tx.uuid] = _compute(tx);
    }
    return fxs[tx.uuid];
  }
}
