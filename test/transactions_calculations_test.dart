import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/features/transactions/calculations.dart';
import 'package:jxledger/features/transactions/model.dart';

Decimal _d(String value) => Decimal.parse(value);

TransactionsModel _tx({
  required String id,
  String srAmount = '10',
  String rrAmount = '20',
  String balance = '20',
  int srId = 1,
  int rrId = 2,
  TransactionStatus status = TransactionStatus.active,
  String parentId = 'root',
  String rootId = 'root',
}) {
  return TransactionsModel(
    tid: id,
    rid: rootId,
    pid: parentId,
    srAmount: _d(srAmount),
    srId: srId,
    rrAmount: _d(rrAmount),
    rrId: rrId,
    balance: _d(balance),
    status: status.index,
    closable: parentId == '0',
    timestamp: DateTime.now().toUtc().microsecondsSinceEpoch - 1000,
    meta: {},
  );
}

void main() {
  const calc = TransactionCalculation();

  group('spreadAmount', () {
    test('spreads by transaction balance and conserves repeating totals exactly', () {
      final txs = [_tx(id: 'a', balance: '1'), _tx(id: 'b', balance: '1'), _tx(id: 'c', balance: '1')];

      final allocations = calc.spreadAmount(_d('100'), txs);

      expect(allocations.keys, containsAll(['a', 'b', 'c']));
      expect(allocations['a'], _d('33.333333333333333333'));
      expect(allocations['b'], _d('33.333333333333333333'));
      expect(allocations['c'], _d('33.333333333333333334'));
      expect(allocations.values.fold<Decimal>(Decimal.zero, (sum, value) => sum + value), _d('100'));
    });

    test('uses exact common-unit multiplication for divisible balances', () {
      final txs = [_tx(id: 'a', balance: '1'), _tx(id: 'b', balance: '2'), _tx(id: 'zero', balance: '0'), _tx(id: 'c', balance: '3')];

      expect(calc.spreadAmount(_d('120'), txs), {'a': _d('20'), 'b': _d('40'), 'zero': Decimal.zero, 'c': _d('60')});
    });

    test('returns zero for no transactions or zero total balance', () {
      expect(calc.spreadAmount(_d('100'), []), isEmpty);
      final txs = [_tx(id: 'zero-a', balance: '0'), _tx(id: 'zero-b', balance: '0')];
      expect(calc.spreadAmount(_d('100'), txs), {'zero-a': Decimal.zero, 'zero-b': Decimal.zero});
    });
  });

  group('balance and rate calculations', () {
    test('calculateBalanceProfit sums profits from eligible transactions', () {
      final txs = [_tx(id: 'a', rrAmount: '20', balance: '25'), _tx(id: 'b', rrAmount: '10', balance: '13')];

      expect(calc.calculateBalanceProfit(txs), _d('8'));
      expect(calc.calculateBalanceProfit([]), isNull);
      expect(calc.calculateBalanceProfit([_tx(id: 'equal', rrAmount: '20', balance: '20')]), isNull);
      expect(calc.calculateBalanceProfit([_tx(id: 'loss', rrAmount: '20', balance: '19')]), isNull);
      expect(
        calc.calculateBalanceProfit([_tx(id: 'profit', rrAmount: '20', balance: '22'), _tx(id: 'equal', rrAmount: '20', balance: '20')]),
        _d('2'),
      );
    });

    test('cumulativeSourceValue prorates remaining balance and ignores zero result amounts', () {
      final txs = [
        _tx(id: 'partial', srAmount: '20', rrAmount: '40', balance: '10'),
        _tx(id: 'full', srAmount: '8', rrAmount: '20', balance: '20'),
      ];
      expect(calc.cumulativeSourceValue(txs), _d('13'));
      expect(calc.cumulativeSourceValue([]), Decimal.zero);
    });

    test('averageExchangedRate calculates normal and inverse mean rates', () {
      final txs = [_tx(id: 'a', srAmount: '10', rrAmount: '20'), _tx(id: 'b', srAmount: '10', rrAmount: '40')];
      expect(calc.averageExchangedRate(txs), _d('3'));
      expect(calc.averageExchangedRate(txs, reverse: true), _d('0.375'));
      expect(calc.averageExchangedRate([]), Decimal.zero);
    });

    test('source totals support active filtering and partial shrinking', () {
      final txs = [
        _tx(id: 'active', srAmount: '10', rrAmount: '20', balance: '20'),
        _tx(id: 'partial', srAmount: '20', rrAmount: '40', balance: '10', status: TransactionStatus.partial),
        _tx(id: 'closed', srAmount: '30', rrAmount: '40', balance: '5', status: TransactionStatus.closed),
      ];
      expect(calc.totalSourceBalance(txs), _d('60'));
      expect(calc.totalSourceBalance(txs, shrinkPartial: true), _d('45'));
      expect(calc.totalActiveSourceBalance(txs), _d('30'));
      expect(calc.totalSourceBalance([]), Decimal.zero);
      expect(calc.totalActiveSourceBalance([]), Decimal.zero);
    });

    test('total and active balances include the correct transaction statuses', () {
      final txs = [
        _tx(id: 'active', balance: '20'),
        _tx(id: 'partial', balance: '10', status: TransactionStatus.partial),
        _tx(id: 'closed', balance: '5', status: TransactionStatus.closed),
        _tx(id: 'finalized', balance: '7', status: TransactionStatus.finalized),
        _tx(id: 'inactive', balance: '3', status: TransactionStatus.inactive),
      ];
      expect(calc.totalBalance(txs), _d('45'));
      expect(calc.totalActiveBalance(txs), _d('30'));
      expect(calc.totalBalance([]), Decimal.zero);
      expect(calc.totalActiveBalance([]), Decimal.zero);
    });

    test('finalized totals and grouping exclude non-finalized transactions', () {
      final txs = [
        _tx(id: 'a', rrId: 3, balance: '7', status: TransactionStatus.finalized),
        _tx(id: 'b', rrId: 3, balance: '5', status: TransactionStatus.finalized),
        _tx(id: 'c', rrId: 4, balance: '2', status: TransactionStatus.finalized),
        _tx(id: 'active', rrId: 3, balance: '100'),
      ];
      expect(calc.totalFinalizedBalance(txs), _d('14'));
      expect(calc.totalFinalizedGroup(txs), {3: _d('12'), 4: _d('2')});
      expect(calc.totalFinalizedBalance([]), Decimal.zero);
      expect(calc.totalFinalizedGroup([]), isEmpty);
    });
  });

  group('profit and loss calculations', () {
    final profitable = _tx(id: 'profit', srAmount: '4', rrAmount: '12', balance: '12');
    final losing = _tx(id: 'loss', srAmount: '6', rrAmount: '8', balance: '8');

    test('totalProfitLoss supports normal and reverse valuation', () {
      expect(calc.totalProfitLoss([profitable, losing], _d('2')), Decimal.zero);
      expect(calc.totalProfitLoss([profitable, losing], _d('2'), reverse: true), _d('30'));
      expect(calc.totalProfitLoss([], _d('2')), Decimal.zero);
    });

    test('totalProfit and totalLoss isolate positive and negative results', () {
      expect(calc.totalProfit([profitable, losing], _d('2')), _d('2'));
      expect(calc.totalLoss([profitable, losing], _d('2')), _d('-2'));
      expect(calc.totalProfit([], _d('2')), Decimal.zero);
      expect(calc.totalLoss([], _d('2')), Decimal.zero);
    });

    test('finalized transactions use balance and closed or empty balances are ignored', () {
      final finalized = _tx(id: 'final', srAmount: '10', rrAmount: '7', balance: '7', status: TransactionStatus.finalized);
      final closed = _tx(id: 'closed', srAmount: '1', rrAmount: '20', balance: '20', status: TransactionStatus.closed);
      final empty = _tx(id: 'empty', srAmount: '10', rrAmount: '20', balance: '0');
      expect(calc.totalProfitLoss([finalized], _d('100')), _d('-3'));
      expect(calc.totalProfitLoss([closed, empty], _d('2')), Decimal.zero);
    });

    test('partial shrinking adjusts the source amount used for P/L', () {
      final partial = _tx(id: 'partial', srAmount: '10', rrAmount: '20', balance: '10', status: TransactionStatus.partial);
      expect(calc.totalProfitLoss([partial], Decimal.one), Decimal.zero);
      expect(calc.totalProfitLoss([partial], Decimal.one, shrinkPartial: true), _d('5'));
    });

    test('averageProfitLoss divides by transaction count and handles empty input', () {
      final closed = _tx(id: 'closed', srAmount: '1', rrAmount: '2', balance: '2', status: TransactionStatus.closed);
      expect(calc.averageProfitLoss([profitable, closed], _d('2')), Decimal.one);
      expect(calc.averageProfitLoss([], _d('2')), Decimal.zero);
    });

    test('profitLossPercentage returns a source-relative percentage', () {
      final txs = [_tx(id: 'a', srAmount: '4', rrAmount: '12', balance: '12'), _tx(id: 'b', srAmount: '2', rrAmount: '8', balance: '8')];
      expect(calc.profitLossPercentage(txs, _d('2')).toString(), startsWith('66.666666666666666'));
      expect(calc.profitLossPercentage([], _d('2')), Decimal.zero);
    });
  });

  group('totalCapitalUsed', () {
    test('traces leaf capital through its parent and totals root branches', () {
      final root = _tx(id: 'root', srAmount: '100', rrAmount: '100', balance: '75', srId: 1, rrId: 2, parentId: '0', rootId: '0');
      final child = _tx(id: 'child', srAmount: '25', rrAmount: '50', balance: '50', srId: 2, rrId: 3, parentId: 'root', rootId: 'root');
      final txs = [root, child];
      expect(calc.totalCapitalUsed(child, txs: txs), _d('25'));
      expect(calc.totalCapitalUsed(root, txs: txs), _d('25'));
      expect(calc.totalCapitalUsed(child, txsMap: {for (final tx in txs) tx.tid: tx}), _d('25'));
    });

    test('returns zero for missing parents, broken account links, or missing inputs', () {
      final orphan = _tx(id: 'orphan', srAmount: '5', srId: 9, parentId: 'missing', rootId: 'missing');
      final root = _tx(id: 'root', srAmount: '100', rrAmount: '100', balance: '100', srId: 1, rrId: 2, parentId: '0', rootId: '0');
      final mismatch = _tx(id: 'mismatch', srAmount: '5', srId: 9, parentId: 'root', rootId: 'root');
      expect(calc.totalCapitalUsed(orphan), Decimal.zero);
      expect(calc.totalCapitalUsed(orphan, txs: [orphan]), Decimal.zero);
      expect(calc.totalCapitalUsed(mismatch, txs: [root, mismatch]), Decimal.zero);
    });
  });
}
