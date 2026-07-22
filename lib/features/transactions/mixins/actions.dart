import '../controller.dart';
import '../model.dart';

mixin TransactionsMixinsActions {
  late final TransactionsController txController;
  late List<TransactionsModel> txs;

  bool isDeletable = false;
  bool isClosable = false;
  bool isFinalizable = false;
  bool isRefundable = false;
  bool isUpdatable = false;
  bool get isActive => txs.any((tx) => tx.isActive || tx.isPartial);

  void checkForClosable() {
    isClosable = false;

    for (final tx in txs) {
      try {
        final closable = txController.isClosable(tx);
        if (closable) {
          isClosable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void checkForDeletable() {
    isDeletable = false;

    for (final tx in txs) {
      try {
        final deletable = txController.isDeletable(tx);
        if (deletable) {
          isDeletable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void checkForFinalizable() {
    isFinalizable = false;

    for (final tx in txs) {
      try {
        final finalizable = txController.isFinalizable(tx);
        if (finalizable) {
          isFinalizable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void checkForRefundable() {
    isRefundable = false;

    for (final tx in txs) {
      try {
        final refundable = txController.isRefundable(tx);
        if (refundable) {
          isRefundable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  void checkForUpdatable() {
    isUpdatable = false;

    for (final tx in txs) {
      try {
        final updatable = txController.isUpdatable(tx);
        if (updatable) {
          isUpdatable = true;
          break;
        }
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> closeTransactions() async {
    for (final tx in txs) {
      try {
        await txController.closeLeaf(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> finalizeTransactions() async {
    for (final tx in txs) {
      try {
        await txController.finalize(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> deleteTransactions() async {
    for (final tx in txs) {
      try {
        await txController.remove(tx);
      } catch (_) {
        continue;
      }
    }
  }

  Future<void> refundTransactions() async {
    for (final tx in txs) {
      try {
        await txController.removeLeaf(tx);
      } catch (_) {
        continue;
      }
    }
  }
}
