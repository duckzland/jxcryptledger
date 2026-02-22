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

  double averageExchangedRate(List<TransactionsModel> txs) {
    if (txs.isEmpty) return 0.0;

    double totalRate = 0;
    int count = 0;

    for (final tx in txs) {
      if (tx.rrAmount > 0) {
        totalRate += tx.rateDouble;
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

  double averageProfitLoss(List<TransactionsModel> txs, double currentRate) {
    if (txs.isEmpty) return 0.0;

    double totalPL = 0;
    for (final tx in txs) {
      final currentValue = tx.balance / currentRate;
      totalPL += currentValue - tx.balance;
    }

    return totalPL / txs.length;
  }

  double profitLossPercentage(List<TransactionsModel> txs, double currentRate) {
    final avgRate = averageExchangedRate(txs);
    if (avgRate == 0) return 0.0;

    final avgPL = averageProfitLoss(txs, currentRate);
    return (avgPL / avgRate) * 100;
  }
}
