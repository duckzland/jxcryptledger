import 'dart:convert';

import 'package:decimal/decimal.dart';

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
    }

    final children = <String, List<TransactionsModel>>{};
    for (final tx in txs) {
      if (tx.pid.isNotEmpty) {
        children.putIfAbsent(tx.pid, () => []).add(tx);
      }
    }

    final returnedBalances = _calculateReturnedBalances(txs, children, map);

    for (final tx in txs) {
      if (!tx.isLeaf) continue;

      final parent = map[tx.pid]!;
      if (tx.srId != parent.rrId) {
        throw ValidationException(AppErrorCode.txImportSrIdMismatch, "srId mismatch for ${tx.tid}", "Import failed");
      }

      final available = Math.add(parent.rrAmount, returnedBalances[parent.tid] ?? Decimal.zero);
      if (tx.srAmount > available) {
        throw ValidationException(
          AppErrorCode.txImportSrAmountExceedsParent,
          "srAmount exceeds parent available amount for ${tx.tid}",
          "Import failed",
        );
      }
    }

    for (final tx in txs) {
      final list = children[tx.tid] ?? [];
      if (list.isNotEmpty) {
        final sum = list.fold<Decimal>(Decimal.zero, (a, b) => Math.add(a, b.srAmount));
        final available = Math.add(tx.rrAmount, returnedBalances[tx.tid] ?? Decimal.zero);
        if (sum > available) {
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

      if (tx.balance == Decimal.zero) {
        if (tx.status != TransactionStatus.inactive.index && tx.status != TransactionStatus.closed.index) {
          throw ValidationException(
            AppErrorCode.txImportZeroBalanceNotInactive,
            "Zero balance must be inactive for ${tx.tid}",
            "Import failed",
          );
        }
        continue;
      }

      final hasActiveChild = list.any((c) => c.status == TransactionStatus.active.index);

      if (tx.balance > Decimal.zero) {
        if (hasActiveChild) {
          if (tx.status != TransactionStatus.partial.index) {
            throw ValidationException(
              AppErrorCode.txImportNonZeroBalanceNotPartial,
              "Non-zero balance with active children must be partial for ${tx.tid}",
              "Import failed",
            );
          }
        } else {
          if (tx.status != TransactionStatus.active.index &&
              tx.status != TransactionStatus.partial.index &&
              tx.status != TransactionStatus.finalized.index) {
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

  Map<String, Decimal> _calculateReturnedBalances(
    List<TransactionsModel> txs,
    Map<String, List<TransactionsModel>> children,
    Map<String, TransactionsModel> map,
  ) {
    int depthOf(TransactionsModel tx) {
      var depth = 0;
      var parent = map[tx.pid];
      final visited = <String>{tx.tid};

      while (parent != null && visited.add(parent.tid)) {
        depth++;
        if (parent.pid == '0') break;
        parent = map[parent.pid];
      }

      return depth;
    }

    TransactionsModel? closeTarget(TransactionsModel tx) {
      var parent = map[tx.pid];
      while (parent != null) {
        if (parent.rrId == tx.rrId) return parent;
        if (parent.pid == '0') break;
        parent = map[parent.pid];
      }
      return null;
    }

    final ordered = [...txs]..sort((a, b) => depthOf(b).compareTo(depthOf(a)));
    final returnedBalances = <String, Decimal>{};

    for (final tx in ordered) {
      if (!tx.isClosed || (children[tx.tid]?.isNotEmpty ?? false)) continue;

      final target = closeTarget(tx);
      if (target == null) continue;

      final spent = (children[tx.tid] ?? []).fold<Decimal>(Decimal.zero, (sum, child) => Math.add(sum, child.srAmount));
      final available = Math.add(tx.rrAmount, returnedBalances[tx.tid] ?? Decimal.zero);
      final returned = Math.subtract(available, spent);
      if (returned > Decimal.zero) {
        returnedBalances[target.tid] = Math.add(returnedBalances[target.tid] ?? Decimal.zero, returned);
      }
    }

    return returnedBalances;
  }
}
