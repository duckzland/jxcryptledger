import 'dart:convert';

import '../../../app/exceptions.dart';
import '../../../core/math.dart';
import '../model.dart';

class TransactionsRulesImport {
  TransactionsRulesImport();

  List<TransactionsModel> validateJson(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw ValidationException(AppErrorCode.txImportInvalidJSON, "Invalid JSON format", "Import failed");
    }

    final tids = <String>{};
    final List<TransactionsModel> txs = [];

    for (final item in decoded) {
      final tx = TransactionsModel.fromJson(item);
      txs.add(tx);
    }

    for (final tx in txs) {
      if (!tids.add(tx.tid)) {
        throw ValidationException(AppErrorCode.txImportDuplicateTid, "Duplicate TID detected: ${tx.tid}", "Import failed");
      }
    }

    final map = {for (final t in txs) t.tid: t};

    for (final tx in txs) {
      if (tx.pid.isNotEmpty && tx.pid != '0' && !map.containsKey(tx.pid)) {
        throw ValidationException(AppErrorCode.txImportInvalidParent, "Invalid parent: ${tx.pid} for ${tx.tid}", "Import failed");
      }

      if (tx.rid.isNotEmpty && tx.rid != '0' && !map.containsKey(tx.rid)) {
        throw ValidationException(AppErrorCode.txImportInvalidRid, "Invalid rid: ${tx.rid} for ${tx.tid}", "Import failed");
      }

      if (!tx.isRoot && !tx.isLeaf) {
        throw ValidationException(AppErrorCode.txImportInvalidRootStructure, "Invalid root structure for ${tx.tid}", "Import failed");
      }

      if (tx.isLeaf) {
        final parent = map[tx.pid]!;
        if (tx.srId != parent.rrId) {
          throw ValidationException(AppErrorCode.txImportSrIdMismatch, "srId mismatch for ${tx.tid}", "Import failed");
        }
        if (tx.srAmount > parent.rrAmount) {
          throw ValidationException(
            AppErrorCode.txImportSrAmountExceedsParent,
            "srAmount exceeds parent rrAmount for ${tx.tid}",
            "Import failed",
          );
        }
      }
    }

    final children = <String, List<TransactionsModel>>{};
    for (final tx in txs) {
      if (tx.pid.isNotEmpty) {
        children.putIfAbsent(tx.pid, () => []).add(tx);
      }
    }

    for (final tx in txs) {
      final list = children[tx.tid] ?? [];
      if (list.isNotEmpty) {
        final sum = list.fold<double>(0, (a, b) => Math.add(a, b.srAmount));
        if (sum > tx.rrAmount) {
          throw ValidationException(
            AppErrorCode.txImportChildAmountSumExceeded,
            "Child srAmount sum exceeds parent rrAmount for ${tx.tid}",
            "Import failed",
          );
        }
      }
    }

    for (final tx in txs) {
      final list = children[tx.tid] ?? [];

      if (tx.balance == 0) {
        if (tx.status != TransactionStatus.inactive.index) {
          throw ValidationException(
            AppErrorCode.txImportZeroBalanceNotInactive,
            "Zero balance must be inactive for ${tx.tid}",
            "Import failed",
          );
        }
        continue;
      }

      final hasActiveChild = list.any((c) => c.status == TransactionStatus.active.index);

      if (tx.balance > 0) {
        if (hasActiveChild) {
          if (tx.status != TransactionStatus.partial.index) {
            throw ValidationException(
              AppErrorCode.txImportNonZeroBalanceNotPartial,
              "Non-zero balance with active children must be partial for ${tx.tid}",
              "Import failed",
            );
          }
        } else {
          if (tx.status != TransactionStatus.active.index && tx.status != TransactionStatus.finalized.index) {
            throw ValidationException(
              AppErrorCode.txImportNonZeroBalanceNotActive,
              "Non-zero balance without active children must be active or finalized for ${tx.tid}",
              "Import failed",
            );
          }
        }
      }
    }

    for (final tx in txs) {
      if (tx.isRoot) continue;
      TransactionsModel? ancestor = tx;
      bool closable = false;

      while (ancestor != null && ancestor.pid != '0') {
        final p = map[ancestor.pid];
        if (p == null) break;

        if (p.rrId == tx.rrId) {
          closable = true;
          break;
        }

        ancestor = p;
      }

      if (tx.closable != closable) {
        throw ValidationException(AppErrorCode.txImportInvalidClosableState, "Invalid closable state for ${tx.tid}", "Import failed");
      }
    }

    return txs;
  }
}
