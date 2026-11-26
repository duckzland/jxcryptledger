import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/features/transactions/calculations.dart';
import 'package:jxledger/features/transactions/model.dart';

Decimal _decimal(String value) => Decimal.parse(value);

List<TransactionsModel> _largeBranchedTree({
  int descendants = 10000,
  int branchingFactor = 4,
}) {
  final now = DateTime.now().toUtc().microsecondsSinceEpoch;
  final transactions = <TransactionsModel>[
    TransactionsModel(
      tid: 'tx-0',
      rid: '0',
      pid: '0',
      srAmount: _decimal('100000'),
      srId: 1,
      rrAmount: _decimal('100000'),
      rrId: 2,
      balance: _decimal('100000'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: now - descendants - 1,
      meta: const {},
    ),
  ];

  for (var index = 1; index <= descendants; index++) {
    final parentIndex = (index - 1) ~/ branchingFactor;
    final parent = transactions[parentIndex];
    final status =
        TransactionStatus.values[index % TransactionStatus.values.length];

    transactions.add(
      TransactionsModel(
        tid: 'tx-$index',
        rid: 'tx-0',
        pid: parent.tid,
        srAmount: _decimal(index % 3 == 0 ? '12.5' : '10'),
        srId: parent.rrId,
        rrAmount: _decimal('20'),
        rrId: index + 2,
        balance: _decimal(index % 7 == 0 ? '8' : '20'),
        status: status.index,
        closable: parentIndex == 0,
        timestamp: now - descendants + index,
        meta: const {},
      ),
    );
  }

  return transactions;
}

void main() {
  const calculation = TransactionCalculation();
  const descendants = 10000;
  final transactions = _largeBranchedTree(descendants: descendants);
  final transactionsById = {for (final tx in transactions) tx.tid: tx};
  final transactionsByParent = <String, List<TransactionsModel>>{};
  final transactionsByRoot = <String, Map<String, TransactionsModel>>{};
  final rate = _decimal('2.5');

  for (final tx in transactions) {
    final rootId = tx.isRoot ? tx.tid : tx.rid;
    transactionsByParent
        .putIfAbsent(tx.pid, () => <TransactionsModel>[])
        .add(tx);
    transactionsByRoot.putIfAbsent(
      rootId,
      () => <String, TransactionsModel>{},
    )[tx.tid] = tx;
  }

  test('profiles calculations with a 10,001-transaction branched tree', () {
    expect(transactions, hasLength(descendants + 1));
    expect(transactions[1].pid, transactions.first.tid);
    expect(transactions[5].pid, transactions[1].tid);

    void measure(String name, Object? Function() operation) {
      // Warmup JIT compiler before timing
      for (var i = 0; i < 3; i++) {
        operation();
      }

      const repetitions = 20;
      final stopwatch = Stopwatch()..start();
      // ignore: unused_local_variable
      Object? result;
      for (var iteration = 0; iteration < repetitions; iteration++) {
        result = operation();
      }
      stopwatch.stop();

      final averageMicroseconds = stopwatch.elapsedMicroseconds / repetitions;
      // ignore: avoid_print
      print('$name: ${averageMicroseconds.toStringAsFixed(1)} us/op');
    }

    final root = transactions.first;
    final leaf = transactions.last;

    measure(
      'spreadAmount',
      () => calculation.spreadAmount(_decimal('100000'), transactions),
    );
    measure(
      'cumulativeSourceValue',
      () => calculation.cumulativeSourceValue(transactions),
    );
    measure(
      'averageExchangedRate',
      () => calculation.averageExchangedRate(transactions),
    );
    measure(
      'averageExchangedRate(reverse)',
      () => calculation.averageExchangedRate(transactions, reverse: true),
    );
    measure(
      'totalSourceBalance',
      () => calculation.totalSourceBalance(transactions),
    );
    measure(
      'totalSourceBalance(shrinkPartial)',
      () => calculation.totalSourceBalance(transactions, shrinkPartial: true),
    );
    measure(
      'totalActiveSourceBalance',
      () => calculation.totalActiveSourceBalance(transactions),
    );
    measure('totalBalance', () => calculation.totalBalance(transactions));
    measure(
      'totalActiveBalance',
      () => calculation.totalActiveBalance(transactions),
    );
    measure(
      'calculateBalanceProfit',
      () => calculation.calculateBalanceProfit(transactions),
    );
    measure(
      'totalFinalizedBalance',
      () => calculation.totalFinalizedBalance(transactions),
    );
    measure(
      'totalFinalizedGroup',
      () => calculation.totalFinalizedGroup(transactions),
    );
    measure(
      'averageProfitLoss',
      () => calculation.averageProfitLoss(transactions, rate),
    );
    measure(
      'totalProfitLoss',
      () => calculation.totalProfitLoss(transactions, rate),
    );
    measure('totalProfit', () => calculation.totalProfit(transactions, rate));
    measure('totalLoss', () => calculation.totalLoss(transactions, rate));
    measure(
      'profitLossPercentage',
      () => calculation.profitLossPercentage(transactions, rate),
    );
    measure(
      'totalCapitalUsed(leaf)',
      () => calculation.totalCapitalUsed(
        leaf,
        txsMap: transactionsByRoot[root.tid],
        txsByParent: transactionsByParent,
      ),
    );
    measure(
      'totalCapitalUsed(root)',
      () => calculation.totalCapitalUsed(
        root,
        txsMap: transactionsById,
        txsByParent: transactionsByParent,
      ),
    );
    measure('totalCapitalUsed(all transactions)', () {
      Decimal total = Decimal.zero;
      for (final tx in transactions) {
        total += calculation.totalCapitalUsed(
          tx,
          txsMap: transactionsByRoot[tx.isRoot ? tx.tid : tx.rid],
          txsByParent: transactionsByParent,
        );
      }
      return total;
    });
  });
}
