import '../../core/math.dart';
import 'model.dart';

class TransactionCalculation {
  const TransactionCalculation();

  double cumulativeSourceValue(List<TransactionsModel> txs) {
    double total = 0;
    for (final tx in txs) {
      if (tx.rrAmount > 0) {
        final percentageLeft = Math.divide(tx.balance, tx.rrAmount);
        total = Math.add(total, Math.multiply(percentageLeft, tx.srAmount));
      }
    }
    return total;
  }

  double averageExchangedRate(List<TransactionsModel> txs, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalRate = 0;
    int count = 0;

    for (final tx in txs) {
      if (tx.rrAmount > 0) {
        final rate = reverse && tx.rateDouble != 0 ? Math.divide(1, tx.rateDouble) : tx.rateDouble;

        totalRate = Math.add(totalRate, rate);
        count++;
      }
    }

    return count > 0 ? Math.divide(totalRate, count.toDouble()) : 0.0;
  }

  double totalSourceBalance(List<TransactionsModel> txs) {
    return txs.fold<double>(0, (sum, tx) => Math.add(sum, tx.srAmount));
  }

  double totalBalance(List<TransactionsModel> txs) {
    return txs.fold<double>(0, (sum, tx) => Math.add(sum, tx.balance));
  }

  double averageProfitLoss(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalPL = totalProfitLoss(txs, currentRate);
    return Math.divide(totalPL, txs.length.toDouble());
  }

  double totalProfitLoss(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalPL = 0;

    for (final tx in txs) {
      final currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);

      totalPL = Math.add(totalPL, Math.subtract(currentValue, tx.srAmount));
    }

    return totalPL;
  }

  double totalProfit(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalPL = 0;

    for (final tx in txs) {
      final currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);
      final pol = Math.subtract(currentValue, tx.srAmount);
      if (pol > 0) {
        totalPL = Math.add(totalPL, pol);
      }
    }

    return totalPL;
  }

  double totalLoss(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalPL = 0;

    for (final tx in txs) {
      final currentValue = reverse ? Math.multiply(tx.balance, currentRate) : Math.divide(tx.balance, currentRate);
      final pol = Math.subtract(currentValue, tx.srAmount);
      if (pol < 0) {
        totalPL = Math.add(totalPL, pol);
      }
    }

    return totalPL;
  }

  double profitLossPercentage(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    final totalBalance = totalSourceBalance(txs);
    if (totalBalance == 0) return 0.0;

    final avgPL = averageProfitLoss(txs, currentRate, reverse: reverse);
    final totalPL = Math.multiply(avgPL, txs.length.toDouble());

    return Math.multiply(Math.divide(totalPL, totalBalance), 100);
  }
}
