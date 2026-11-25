import 'package:decimal/decimal.dart';

import '../../core/math.dart';
import 'model.dart';

class TransactionCalculation {
  const TransactionCalculation();

  TransactionsModel? getCloseTargetParent(TransactionsModel tx, {List<TransactionsModel>? txs, Map<String, TransactionsModel>? txsMap}) {
    if (tx.isRoot) return null;
    if (txs == null && txsMap == null) return null;

    txsMap ??= {for (final item in txs!) item.tid: item};

    String pid = tx.pid;
    while (pid.isNotEmpty && pid != '0') {
      final p = txsMap[pid];
      if (p == null) break;

      if (p.rrId == tx.rrId) {
        return p;
      }

      pid = p.pid;
    }

    if (tx.rid.isNotEmpty && tx.rid != '0') {
      final root = txsMap[tx.rid];
      if (root != null && root.isRoot && root.rrId == tx.rrId) {
        return root;
      }
    }

    return null;
  }

  Map<String, Decimal> spreadByWeights(Decimal amount, Iterable<TransactionsModel> transactions, Map<String, Decimal> weights) {
    final txList = transactions.toList();
    final totalWeight = txList.fold<Decimal>(Decimal.zero, (total, tx) {
      final w = weights[tx.uuid] ?? Decimal.zero;
      return w > Decimal.zero ? Math.add(total, w) : total;
    });

    if (totalWeight <= Decimal.zero) {
      return {for (final tx in txList) tx.uuid: Decimal.zero};
    }

    final lastPositive = txList.lastIndexWhere((tx) => (weights[tx.uuid] ?? Decimal.zero) > Decimal.zero);

    final allocations = <String, Decimal>{};
    var allocated = Decimal.zero;
    final unitAmount = Math.divide(amount, totalWeight);

    for (var index = 0; index < txList.length; index++) {
      final tx = txList[index];
      final weight = weights[tx.uuid] ?? Decimal.zero;
      if (weight <= Decimal.zero) {
        allocations[tx.uuid] = Decimal.zero;
        continue;
      }

      final allocation = index == lastPositive ? Math.subtract(amount, allocated) : Math.multiply(unitAmount, weight);
      allocations[tx.uuid] = allocation;
      allocated = Math.add(allocated, allocation);
    }

    return allocations;
  }

  Map<String, Decimal> spreadAmount(Decimal amount, Iterable<TransactionsModel> transactions) {
    final txList = transactions.toList();
    return spreadByWeights(amount, txList, {for (final tx in txList) tx.uuid: tx.balance});
  }

  Decimal cumulativeSourceValue(List<TransactionsModel> txs) {
    Decimal total = Decimal.zero;

    for (int i = 0; i < txs.length; i++) {
      final tx = txs[i];
      if (tx.rrAmount <= Decimal.zero || tx.balance == Decimal.zero) continue;

      if (tx.balance == tx.rrAmount) {
        total = Math.add(total, tx.srAmount);
        continue;
      }

      total = Math.add(total, Math.divide(Math.multiply(tx.balance, tx.srAmount), tx.rrAmount));
    }

    return total;
  }

  Decimal averageExchangedRate(List<TransactionsModel> txs, {bool reverse = false}) {
    Decimal totalRate = Decimal.zero;
    int count = 0;

    for (int i = 0; i < txs.length; i++) {
      final tx = txs[i];
      if (tx.rrAmount <= Decimal.zero) continue;

      final rate = reverse ? tx.reverseRate : tx.rate;
      if (rate != Decimal.zero) {
        totalRate = Math.add(totalRate, rate);
      }
      count++;
    }

    return count > 0 ? Math.divide(totalRate, count.toDecimal()) : Decimal.zero;
  }

  Decimal totalSourceBalance(List<TransactionsModel> txs, {bool shrinkPartial = false}) {
    return txs.fold<Decimal>(Decimal.zero, (sum, tx) {
      Decimal srAmount = tx.srAmount;

      if (shrinkPartial && tx.isPartial) {
        srAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
      }

      return Math.add(sum, srAmount);
    });
  }

  Decimal totalActiveSourceBalance(List<TransactionsModel> txs) {
    return txs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, (tx.isActive || tx.isPartial) ? tx.srAmount : Decimal.zero));
  }

  Decimal totalBalance(List<TransactionsModel> txs) {
    return txs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, tx.balance));
  }

  Decimal totalActiveBalance(List<TransactionsModel> txs) {
    return txs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, (tx.isActive || tx.isPartial) ? tx.balance : Decimal.zero));
  }

  Decimal? calculateBalanceProfit(List<TransactionsModel> txs) {
    final profitableTxs = txs.where((tx) => tx.balance > tx.rrAmount);
    if (profitableTxs.isEmpty) return null;

    return profitableTxs.fold<Decimal>(Decimal.zero, (total, tx) => Math.add(total, Math.subtract(tx.balance, tx.rrAmount)));
  }

  Decimal totalFinalizedBalance(List<TransactionsModel> txs) {
    return txs.fold<Decimal>(Decimal.zero, (sum, tx) => Math.add(sum, (tx.isFinalized) ? tx.balance : Decimal.zero));
  }

  Map<int, Decimal> totalFinalizedGroup(List<TransactionsModel> txs) {
    final map = <int, Decimal>{};

    for (final tx in txs) {
      if (!tx.isFinalized) continue;

      final key = tx.rrId;
      final current = map[key] ?? Decimal.zero;

      map[key] = Math.add(current, tx.balance);
    }

    return map;
  }

  Decimal averageProfitLoss(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    if (txs.isEmpty) return Decimal.zero;
    Decimal totalPL = totalProfitLoss(txs, currentRate, reverse: reverse, shrinkPartial: shrinkPartial);

    return Math.divide(totalPL, txs.length.toDecimal());
  }

  Decimal totalProfitLoss(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    Decimal finalizedBalanceSum = Decimal.zero;
    Decimal unfinalizedBalanceSum = Decimal.zero;
    Decimal totalSrSum = Decimal.zero;

    for (int i = 0; i < txs.length; i++) {
      final tx = txs[i];
      if (tx.isClosed || tx.balance == Decimal.zero) continue;

      final srAmount = (shrinkPartial && tx.isPartial) ? Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount) : tx.srAmount;

      totalSrSum = Math.add(totalSrSum, srAmount);

      if (tx.isFinalized) {
        finalizedBalanceSum = Math.add(finalizedBalanceSum, tx.balance);
      } else {
        unfinalizedBalanceSum = Math.add(unfinalizedBalanceSum, tx.balance);
      }
    }

    final unfinalizedValue = unfinalizedBalanceSum == Decimal.zero
        ? Decimal.zero
        : (reverse ? Math.multiply(unfinalizedBalanceSum, currentRate) : Math.divide(unfinalizedBalanceSum, currentRate));

    final totalValue = Math.add(finalizedBalanceSum, unfinalizedValue);
    return Math.subtract(totalValue, totalSrSum);
  }

  Decimal totalProfit(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    Decimal totalPL = Decimal.zero;

    for (int i = 0; i < txs.length; i++) {
      final tx = txs[i];
      if (tx.isClosed || tx.balance == Decimal.zero) continue;

      final srAmount = (shrinkPartial && tx.isPartial) ? Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount) : tx.srAmount;

      if (tx.isFinalized) {
        if (tx.balance > srAmount) {
          totalPL = Math.add(totalPL, Math.subtract(tx.balance, srAmount));
        }
        continue;
      }

      if (reverse) {
        final currentValue = Math.multiply(tx.balance, currentRate);
        if (currentValue > srAmount) {
          totalPL = Math.add(totalPL, Math.subtract(currentValue, srAmount));
        }
        continue;
      }

      if (tx.balance > Math.multiply(srAmount, currentRate)) {
        final currentValue = Math.divide(tx.balance, currentRate);
        totalPL = Math.add(totalPL, Math.subtract(currentValue, srAmount));
      }
    }

    return totalPL;
  }

  Decimal totalLoss(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    Decimal finalizedLoss = Decimal.zero;
    Decimal unfinalizedBalanceSum = Decimal.zero;
    Decimal unfinalizedSrSum = Decimal.zero;

    for (int i = 0; i < txs.length; i++) {
      final tx = txs[i];
      if (tx.isClosed || tx.balance == Decimal.zero) continue;

      final srAmount = (shrinkPartial && tx.isPartial) ? Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount) : tx.srAmount;

      if (tx.isFinalized) {
        if (tx.balance < srAmount) {
          finalizedLoss = Math.add(finalizedLoss, Math.subtract(tx.balance, srAmount));
        }
        continue;
      }

      if (reverse) {
        if (Math.multiply(tx.balance, currentRate) < srAmount) {
          unfinalizedBalanceSum = Math.add(unfinalizedBalanceSum, tx.balance);
          unfinalizedSrSum = Math.add(unfinalizedSrSum, srAmount);
        }
        continue;
      }

      if (tx.balance < Math.multiply(srAmount, currentRate)) {
        unfinalizedBalanceSum = Math.add(unfinalizedBalanceSum, tx.balance);
        unfinalizedSrSum = Math.add(unfinalizedSrSum, srAmount);
      }
    }

    if (unfinalizedBalanceSum == Decimal.zero && unfinalizedSrSum == Decimal.zero) {
      return finalizedLoss;
    }

    final unfinalizedValue = reverse ? Math.multiply(unfinalizedBalanceSum, currentRate) : Math.divide(unfinalizedBalanceSum, currentRate);

    return Math.add(finalizedLoss, Math.subtract(unfinalizedValue, unfinalizedSrSum));
  }

  Decimal profitLossPercentage(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    if (txs.isEmpty) return Decimal.zero;

    final totalBalance = totalSourceBalance(txs, shrinkPartial: shrinkPartial);
    if (totalBalance == Decimal.zero) return Decimal.zero;

    final totalPL = totalProfitLoss(txs, currentRate, reverse: reverse, shrinkPartial: shrinkPartial);

    return Math.multiply(Math.divide(totalPL, totalBalance), Decimal.fromInt(100));
  }

  Decimal totalCapitalUsed(
    TransactionsModel leaf, {
    List<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
    Map<String, List<TransactionsModel>>? txsByParent,
  }) {
    if (txs == null && txsMap == null) return Decimal.zero;
    txsMap ??= {for (final tx in txs!) tx.tid: tx};

    if (leaf.isRoot) {
      Decimal used = Decimal.zero;
      final children = txsByParent?[leaf.tid] ?? txsMap.values.where((tx) => tx.pid == leaf.tid);
      for (final tx in children) {
        if (tx.tid == leaf.tid) continue;
        used = Math.add(used, totalCapitalUsed(tx, txsMap: txsMap, txsByParent: txsByParent));
      }
      return used;
    }

    TransactionsModel? current = leaf;
    Decimal? num;
    Decimal? den;

    while (current != null) {
      if (current.isRoot) {
        if (num == null) return current.srAmount;
        return Math.divide(Math.multiply(current.srAmount, num), den!);
      }

      final parent = txsMap[current.pid];
      if (parent == null || parent.rrId != current.srId) {
        return Decimal.zero;
      }

      Decimal capitalAmount = current.srAmount;
      if (parent.profitAmount > Decimal.zero) {
        if (capitalAmount <= parent.profitAmount) return Decimal.zero;
        capitalAmount = Math.subtract(capitalAmount, parent.profitAmount);
      }

      if (num == null) {
        num = capitalAmount;
        den = parent.rrAmount;
      } else {
        num = Math.multiply(num, capitalAmount);
        den = Math.multiply(den!, parent.rrAmount);
      }

      current = parent;
    }

    return Decimal.zero;
  }

  Decimal totalCompoundedProfitLoss(TransactionsModel tx, {List<TransactionsModel>? txs, Map<String, TransactionsModel>? txsMap}) {
    if (txs == null && txsMap == null) return tx.profitAmount;
    txsMap ??= {for (final item in txs!) item.tid: item};

    TransactionsModel? ptx = getCloseTargetParent(tx, txsMap: txsMap);
    if (ptx == null) {
      return tx.profitAmount;
    }

    while (true) {
      final next = getCloseTargetParent(ptx!, txsMap: txsMap);
      if (next == null) break;

      // Collect ancestor path from tx up to ptx
      final activeAncestors = <String>{};
      TransactionsModel? cursor = tx;
      bool blocked = false;
      while (cursor != null) {
        activeAncestors.add(cursor.tid);
        if (cursor.tid != tx.tid && cursor.tid != ptx.tid && cursor.statusEnum != TransactionStatus.inactive) {
          blocked = true;
          break;
        }
        if (cursor.tid == ptx.tid || cursor.pid.isEmpty || cursor.pid == '0') break;
        cursor = txsMap[cursor.pid];
      }

      // Also stop if ptx has any other open/partial descendant outside the active branch
      if (!blocked) {
        for (final node in txsMap.values) {
          if (node.tid == ptx.tid || activeAncestors.contains(node.tid)) continue;

          String pid = node.pid;
          while (pid.isNotEmpty && pid != '0') {
            if (pid == ptx.tid) {
              if (node.statusEnum != TransactionStatus.closed && node.statusEnum != TransactionStatus.inactive) {
                blocked = true;
              }
              break;
            }
            pid = txsMap[pid]?.pid ?? '';
          }
          if (blocked) break;
        }
      }

      if (blocked) break;
      ptx = next;
    }

    final sharePercentage = totalCompoundedSharePercentage(tx, targetParent: ptx, txsMap: txsMap);

    final effectivePrincipal = Math.divide(Math.multiply(ptx.rrAmount, sharePercentage), Decimal.fromInt(100));

    return Math.subtract(tx.balance, effectivePrincipal);
  }

  Decimal totalCompoundedSharePercentage(
    TransactionsModel tx, {
    TransactionsModel? targetParent,
    List<TransactionsModel>? txs,
    Map<String, TransactionsModel>? txsMap,
  }) {
    final hundred = Decimal.fromInt(100);
    if (txs == null && txsMap == null) return hundred;
    txsMap ??= {for (final item in txs!) item.tid: item};

    TransactionsModel? ptx = targetParent ?? getCloseTargetParent(tx, txsMap: txsMap);
    if (ptx == null) {
      return hundred;
    }

    if (targetParent == null) {
      while (true) {
        final next = getCloseTargetParent(ptx!, txsMap: txsMap);
        if (next == null) break;

        final activeAncestors = <String>{};
        TransactionsModel? cursor = tx;
        bool blocked = false;
        while (cursor != null) {
          activeAncestors.add(cursor.tid);
          if (cursor.tid != tx.tid && cursor.tid != ptx.tid && cursor.statusEnum != TransactionStatus.inactive) {
            blocked = true;
            break;
          }
          if (cursor.tid == ptx.tid || cursor.pid.isEmpty || cursor.pid == '0') break;
          cursor = txsMap[cursor.pid];
        }

        if (!blocked) {
          for (final node in txsMap.values) {
            if (node.tid == ptx.tid || activeAncestors.contains(node.tid)) continue;

            String pid = node.pid;
            while (pid.isNotEmpty && pid != '0') {
              if (pid == ptx.tid) {
                if (node.statusEnum != TransactionStatus.closed && node.statusEnum != TransactionStatus.inactive) {
                  blocked = true;
                }
                break;
              }
              pid = txsMap[pid]?.pid ?? '';
            }
            if (blocked) break;
          }
        }

        if (blocked) break;
        ptx = next;
      }
    }

    TransactionsModel? current = tx;
    Decimal num = Decimal.one;
    Decimal den = Decimal.one;

    while (current != null && current.tid != ptx.tid) {
      if (current.isRoot || current.pid.isEmpty || current.pid == '0') break;

      final parent = txsMap[current.pid];
      if (parent == null) break;

      if (parent.rrId == current.srId && parent.rrAmount > Decimal.zero) {
        if (current.srAmount < parent.rrAmount) {
          num = Math.multiply(num, current.srAmount);
          den = Math.multiply(den, parent.rrAmount);
        }
      }

      current = parent;
    }

    if (den == Decimal.one) {
      return Math.multiply(hundred, num);
    }

    return Math.divide(Math.multiply(hundred, num), den);
  }
}
