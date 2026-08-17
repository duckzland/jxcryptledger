import 'package:decimal/decimal.dart';

import '../../core/math.dart';
import 'model.dart';

class TransactionCalculation {
  const TransactionCalculation();

  Decimal cumulativeSourceValue(List<TransactionsModel> txs) {
    Decimal total = Decimal.zero;
    for (final tx in txs) {
      if (tx.rrAmount > Decimal.zero) {
        final percentageLeft = Math.divide(tx.balance, tx.rrAmount);
        total = Math.add(total, Math.multiply(percentageLeft, tx.srAmount));
      }
    }
    return total;
  }

  Decimal averageExchangedRate(List<TransactionsModel> txs, {bool reverse = false}) {
    if (txs.isEmpty) return Decimal.zero;

    Decimal totalRate = Decimal.zero;
    int count = 0;

    for (final tx in txs) {
      if (tx.rrAmount > Decimal.zero) {
        final Decimal rate = reverse && tx.rate != Decimal.zero ? Math.divide(Decimal.one, tx.rate) : tx.rate;

        totalRate = Math.add(totalRate, rate);
        count++;
      }
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
    if (txs.isEmpty) return Decimal.zero;

    Decimal totalPL = Decimal.zero;

    for (final tx in txs) {
      if (tx.isClosed || tx.balance == Decimal.zero) {
        continue;
      }

      Decimal currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);

      if (tx.isFinalized) {
        currentValue = tx.balance;
      }

      Decimal srAmount = tx.srAmount;

      if (shrinkPartial && tx.isPartial) {
        srAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
      }

      totalPL = Math.add(totalPL, Math.subtract(currentValue, srAmount));
    }

    return totalPL;
  }

  Decimal totalProfit(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    if (txs.isEmpty) return Decimal.zero;

    Decimal totalPL = Decimal.zero;

    for (final tx in txs) {
      if (tx.isClosed || tx.balance == Decimal.zero) {
        continue;
      }

      Decimal currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);

      if (tx.isFinalized) {
        currentValue = tx.balance;
      }

      Decimal srAmount = tx.srAmount;

      if (shrinkPartial && tx.isPartial) {
        srAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
      }

      final pol = Math.subtract(currentValue, srAmount);
      if (pol > Decimal.zero) {
        totalPL = Math.add(totalPL, pol);
      }
    }

    return totalPL;
  }

  Decimal totalLoss(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    if (txs.isEmpty) return Decimal.zero;

    Decimal totalPL = Decimal.zero;

    for (final tx in txs) {
      if (tx.isClosed || tx.balance == Decimal.zero) {
        continue;
      }

      Decimal currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);

      if (tx.isFinalized) {
        currentValue = tx.balance;
      }

      Decimal srAmount = tx.srAmount;

      if (shrinkPartial && tx.isPartial) {
        srAmount = Math.multiply(Math.divide(tx.balance, tx.rrAmount), tx.srAmount);
      }

      final pol = Math.subtract(currentValue, srAmount);
      if (pol < Decimal.zero) {
        totalPL = Math.add(totalPL, pol);
      }
    }

    return totalPL;
  }

  Decimal profitLossPercentage(List<TransactionsModel> txs, Decimal currentRate, {bool reverse = false, bool shrinkPartial = false}) {
    if (txs.isEmpty) return Decimal.zero;

    final totalBalance = totalSourceBalance(txs, shrinkPartial: shrinkPartial);
    if (totalBalance == Decimal.zero) return Decimal.zero;

    final avgPL = averageProfitLoss(txs, currentRate, reverse: reverse, shrinkPartial: shrinkPartial);

    final totalPL = Math.multiply(avgPL, txs.length.toDecimal());

    return Math.multiply(Math.divide(totalPL, totalBalance), Decimal.fromInt(100));
  }

  Decimal totalCapitalUsed(TransactionsModel leaf, List<TransactionsModel> txs) {
    TransactionsModel? current = leaf;

    final Map<String, TransactionsModel> txMap = {for (final tx in txs) tx.tid: tx};
    Decimal trackedAmount = current.srAmount;

    while (current != null) {
      if (current.pid == "0" && current.rid == "0") {
        return trackedAmount;
      }

      final parent = txMap[current.pid];
      if (parent == null || parent.rrId != current.srId) {
        return Decimal.zero;
      }

      if (parent.balance > parent.rrAmount) {
        final profitSurplus = Math.subtract(parent.balance, parent.rrAmount);

        if (trackedAmount <= profitSurplus) {
          return Decimal.zero;
        }

        trackedAmount = Math.subtract(trackedAmount, profitSurplus);
      }

      final conversionFactor = (parent.rrAmount == Decimal.zero) ? Decimal.one : Math.divide(parent.srAmount, parent.rrAmount);

      trackedAmount = Math.multiply(trackedAmount, conversionFactor);

      current = parent;
    }

    return Decimal.zero;
  }
}
