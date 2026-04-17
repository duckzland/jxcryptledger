import '../controller.dart';
import '../model.dart';

mixin TransactionsMixinsActions {
  late final TransactionsController txController;
  late List<TransactionsModel> txs;

  bool isDeletable = false;
  bool isClosable = false;
  bool isFinalizable = false;

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
}
