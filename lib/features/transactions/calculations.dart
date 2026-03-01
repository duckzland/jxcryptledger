import 'model.dart';

class TransactionCalculation {
  const TransactionCalculation();

  double cumulativeSourceValue(List<TransactionsModel> txs) {
    double total = 0;
    for (final tx in txs) {
      if (tx.rrAmount > 0) {
        final percentageLeft = tx.balance / tx.rrAmount;
        total += percentageLeft * tx.srAmount;
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
        final rate = reverse && tx.rateDouble != 0 ? 1 / tx.rateDouble : tx.rateDouble;

        totalRate += rate;
        count++;
      }
    }

    return count > 0 ? totalRate / count : 0.0;
  }

  double totalSourceBalance(List<TransactionsModel> txs) {
    return txs.fold<double>(0, (sum, tx) => sum + tx.srAmount);
  }

  double totalBalance(List<TransactionsModel> txs) {
    return txs.fold<double>(0, (sum, tx) => sum + tx.balance);
  }

  double averageProfitLoss(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    double totalPL = 0;

    for (final tx in txs) {
      final currentValue = reverse ? tx.balance * currentRate : tx.balance / currentRate;

      totalPL += currentValue - tx.srAmount;
    }

    return totalPL / txs.length;
  }

  double profitLossPercentage(List<TransactionsModel> txs, double currentRate, {bool reverse = false}) {
    if (txs.isEmpty) return 0.0;

    final totalBalance = totalSourceBalance(txs);
    if (totalBalance == 0) return 0.0;

    final avgPL = averageProfitLoss(txs, currentRate, reverse: reverse);
    final totalPL = avgPL * txs.length;

    return (totalPL / totalBalance) * 100;
  }
}
