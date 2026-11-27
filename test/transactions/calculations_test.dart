import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/features/transactions/calculations.dart';
import 'package:jxledger/features/transactions/helper.dart';
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

    group('spreadByWeights', () {
      test('spreads proportionally by custom weights and absorbs repeating remainder on last positive tx', () {
        final txs = [
          _tx(id: 'a', balance: '999'), // balance ignored because weights map takes precedence
          _tx(id: 'b', balance: '888'),
          _tx(id: 'c', balance: '777'),
          _tx(id: 'd', balance: '666'), // trailing zero weight must NOT become lastPositive
        ];
        final weights = <String, Decimal>{'a': _d('1'), 'b': _d('1'), 'c': _d('1'), 'd': _d('0')};

        final allocations = calc.spreadByWeights(_d('100'), txs, weights);

        expect(allocations.keys, containsAll(['a', 'b', 'c', 'd']));
        expect(allocations['a'], _d('33.333333333333333333'));
        expect(allocations['b'], _d('33.333333333333333333'));
        // 'c' is the last positive tx, so it absorbs the repeating remainder
        expect(allocations['c'], _d('33.333333333333333334'));
        expect(allocations['d'], Decimal.zero);
        expect(allocations.values.fold<Decimal>(Decimal.zero, (sum, value) => sum + value), _d('100'));
      });

      test('conserves total accurately when totalWeight >= 10 shifts decimal scale', () {
        final txs = [_tx(id: 'a'), _tx(id: 'b'), _tx(id: 'c')];
        final weights = <String, Decimal>{'a': _d('10'), 'b': _d('10'), 'c': _d('10')};

        final allocations = calc.spreadByWeights(_d('100'), txs, weights);

        expect(allocations['a'], _d('33.33333333333333333'));
        expect(allocations['b'], _d('33.33333333333333333'));
        expect(allocations['c'], _d('33.33333333333333334'));
        expect(allocations.values.fold<Decimal>(Decimal.zero, (sum, value) => sum + value), _d('100'));
      });

      test('ignores negative weights, missing tx ids, and extra keys not in transactions', () {
        final txs = [_tx(id: 'a'), _tx(id: 'b'), _tx(id: 'c'), _tx(id: 'missing')];
        final weights = <String, Decimal>{
          'a': _d('25'),
          'b': _d('-50'), // negative weight ignored
          'c': _d('75'),
          'extra_unlisted': _d('500'), // key not in `txs` must not dilute totalWeight
        };

        final allocations = calc.spreadByWeights(_d('200'), txs, weights);

        expect(allocations['a'], _d('50')); // 25 / (25 + 75) * 200
        expect(allocations['b'], Decimal.zero);
        expect(allocations['c'], _d('150')); // 75 / (25 + 75) * 200
        expect(allocations['missing'], Decimal.zero);
        expect(allocations.containsKey('extra_unlisted'), isFalse);
        expect(allocations.values.fold<Decimal>(Decimal.zero, (sum, value) => sum + value), _d('200'));
      });

      test('accepts lazy Iterable<TransactionsModel> and returns all zeros when total weight <= 0', () {
        final txs = [_tx(id: 'a', balance: '100'), _tx(id: 'b', balance: '200'), _tx(id: 'excluded', balance: '300')];
        final zeroWeights = <String, Decimal>{'a': Decimal.zero, 'b': _d('-10'), 'excluded': _d('500')};

        final lazySelected = txs.where((tx) => tx.uuid != 'excluded');
        final allocations = calc.spreadByWeights(_d('100'), lazySelected, zeroWeights);

        expect(allocations.keys, containsAll(['a', 'b']));
        expect(allocations.containsKey('excluded'), isFalse);
        expect(allocations['a'], Decimal.zero);
        expect(allocations['b'], Decimal.zero);
        expect(calc.spreadByWeights(_d('100'), <TransactionsModel>[], zeroWeights), isEmpty);
      });
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

  group('compounded profit/loss and share percentage', () {
    test('isolates target parent across multi-level branches with unique fractional amounts and mixed srId/rrId', () {
      // Every node uses unique amounts so grabbing any wrong level/sibling is immediately caught:
      //
      // root (COIN 1 -> COIN 2, rrAmount: 1000, balance: 0)
      //  ├── branchA (COIN 2 -> COIN 3, srAmount: 375, rrAmount: 400, balance: 150) [375/1000 = 37.5% of root]
      //  │    ├── a1_step1 (COIN 3 -> COIN 4, srAmount: 250, rrAmount: 310.50, balance: 0) [250/400 = 62.5% of branchA -> 37.5% * 62.5% = 23.4375% of root]
      //  │    │    └── a1_leaf (COIN 4 -> COIN 2, srAmount: 310.50, rrAmount: 412.75, balance: 412.75) [100% of a1_step1 -> closes to root!]
      //  │    └── a2_sibling (COIN 3 -> COIN 5, srAmount: 150, rrAmount: 888.88, balance: 888.88) [decoy sibling, no target]
      //  └── branchB (COIN 2 -> COIN 6, srAmount: 625, rrAmount: 500, balance: 0) [625/1000 = 62.5% of root]
      //       ├── b1_subRoot (COIN 6 -> COIN 7, srAmount: 500, rrAmount: 640, balance: 160) [100% of branchB]
      //       │    ├── b1_mid (COIN 7 -> COIN 8, srAmount: 480, rrAmount: 520.25, balance: 0) [480/640 = 75% of b1_subRoot]
      //       │    │    └── b1_leafWin (COIN 8 -> COIN 7, srAmount: 520.25, rrAmount: 615.40, balance: 615.40) [closes to b1_subRoot, NOT root!]
      //       │    └── b1_siblingDecoy (COIN 7 -> COIN 9, srAmount: 160, rrAmount: 777.77, balance: 777.77) [decoy sibling in b1_subRoot]
      //       └── b2_lossLeaf (COIN 6 -> COIN 2, srAmount: 125, rrAmount: 95.25, balance: 95.25) [125/500 = 25% of branchB -> 62.5% * 25% = 15.625% of root -> closes to root at a loss]

      final root = _tx(id: 'root', srAmount: '1000', rrAmount: '1000', balance: '0', srId: 1, rrId: 2, parentId: '0', rootId: '0');

      // --- Branch A (37.5% of root) ---
      final branchA = _tx(
        id: 'branchA',
        srAmount: '375',
        rrAmount: '400',
        balance: '150',
        srId: 2,
        rrId: 3,
        parentId: 'root',
        rootId: 'root',
      );
      final a1Step1 = _tx(
        id: 'a1_step1',
        srAmount: '250',
        rrAmount: '310.50',
        balance: '0',
        srId: 3,
        rrId: 4,
        parentId: 'branchA',
        rootId: 'root',
      );
      // Share from root: (375 / 1000) * (250 / 400) = 0.375 * 0.625 = 0.234375 -> 23.4375%
      // Effective principal: 1000 * 23.4375% = 234.375
      // Compounded PnL: 412.75 - 234.375 = 178.375
      final a1Leaf = _tx(
        id: 'a1_leaf',
        srAmount: '310.50',
        rrAmount: '412.75',
        balance: '412.75',
        srId: 4,
        rrId: 2,
        parentId: 'a1_step1',
        rootId: 'root',
      );
      // Decoy sibling under branchA with unique balance 888.88
      final a2Sibling = _tx(
        id: 'a2_sibling',
        srAmount: '150',
        rrAmount: '888.88',
        balance: '888.88',
        srId: 3,
        rrId: 5,
        parentId: 'branchA',
        rootId: 'root',
      );

      // --- Branch B (62.5% of root, with inner sub-cycle on COIN 7) ---
      final branchB = _tx(
        id: 'branchB',
        srAmount: '625',
        rrAmount: '500',
        balance: '0',
        srId: 2,
        rrId: 6,
        parentId: 'root',
        rootId: 'root',
      );
      final b1SubRoot = _tx(
        id: 'b1_subRoot',
        srAmount: '500',
        rrAmount: '640',
        balance: '160',
        srId: 6,
        rrId: 7,
        parentId: 'branchB',
        rootId: 'root',
      );
      final b1Mid = _tx(
        id: 'b1_mid',
        srAmount: '480',
        rrAmount: '520.25',
        balance: '0',
        srId: 7,
        rrId: 8,
        parentId: 'b1_subRoot',
        rootId: 'root',
      );
      // Closes to b1_subRoot (COIN 7), NOT root (COIN 2)
      // Share from b1_subRoot: (480 / 640) * (520.25 / 520.25) = 0.75 -> 75%
      // Effective principal: 640 * 75% = 480
      // Compounded PnL: 615.40 - 480 = 135.40
      final b1LeafWin = _tx(
        id: 'b1_leafWin',
        srAmount: '520.25',
        rrAmount: '615.40',
        balance: '615.40',
        srId: 8,
        rrId: 7,
        parentId: 'b1_mid',
        rootId: 'root',
      );
      // Decoy sibling under b1_subRoot with unique balance 777.77
      final b1SiblingDecoy = _tx(
        id: 'b1_siblingDecoy',
        srAmount: '160',
        rrAmount: '777.77',
        balance: '777.77',
        srId: 7,
        rrId: 9,
        parentId: 'b1_subRoot',
        rootId: 'root',
      );
      // Direct child of branchB closing to root (COIN 2) at a loss
      // Share from root: (625 / 1000) * (125 / 500) = 0.625 * 0.25 = 0.15625 -> 15.625%
      // Effective principal: 1000 * 15.625% = 156.25
      // Compounded PnL: 95.25 - 156.25 = -61.00
      final b2LossLeaf = _tx(
        id: 'b2_lossLeaf',
        srAmount: '125',
        rrAmount: '95.25',
        balance: '95.25',
        srId: 6,
        rrId: 2,
        parentId: 'branchB',
        rootId: 'root',
      );

      final txs = [root, branchA, a1Step1, a1Leaf, a2Sibling, branchB, b1SubRoot, b1Mid, b1LeafWin, b1SiblingDecoy, b2LossLeaf];
      final txsMap = {for (final tx in txs) tx.tid: tx};

      // 1. Verify getCloseTargetParent lands on the exact target level
      expect(TransactionsHelper.getCloseTargetParent(root, txsMap: txsMap), isNull);
      expect(TransactionsHelper.getCloseTargetParent(a1Leaf, txsMap: txsMap)?.tid, 'root');
      expect(TransactionsHelper.getCloseTargetParent(b1LeafWin, txsMap: txsMap)?.tid, 'b1_subRoot');
      expect(TransactionsHelper.getCloseTargetParent(b2LossLeaf, txsMap: txsMap)?.tid, isNull);
      expect(TransactionsHelper.getCloseTargetParent(a2Sibling, txsMap: txsMap), isNull);
    });

    test('handles deep linear compounding chain (100 levels) with unique fractional values and decoy sibling', () {
      final txs = <TransactionsModel>[];

      // Root starts with 800 (COIN 1 -> COIN 2)
      txs.add(_tx(id: 'tx_0', srAmount: '800', rrAmount: '800', balance: '500', srId: 1, rrId: 2, parentId: '0', rootId: '0'));

      // Decoy sibling off tx_0 with unique large amount
      txs.add(
        _tx(
          id: 'decoy_sibling',
          srAmount: '500',
          rrAmount: '98765.43',
          balance: '98765.43',
          srId: 2,
          rrId: 999,
          parentId: 'tx_0',
          rootId: 'tx_0',
        ),
      );

      // Step 1 uses 300 out of 800 (37.5%), then compounds 100% with unique fractional increments
      for (int i = 1; i <= 99; i++) {
        final sr = i == 1 ? '300' : '${300 + ((i - 1) * 7.25)}';
        final rr = '${300 + (i * 7.25)}';
        txs.add(
          _tx(id: 'tx_$i', srAmount: sr, rrAmount: rr, balance: '0', srId: i + 1, rrId: i + 2, parentId: 'tx_${i - 1}', rootId: 'tx_0'),
        );
      }

      // Step 100 closes back to COIN 2 (tx_0) with unique fractional balance 1043.85
      final finalLeaf = _tx(
        id: 'tx_100',
        srAmount: '${300 + (99 * 7.25)}',
        rrAmount: '1043.85',
        balance: '1043.85',
        srId: 101,
        rrId: 2,
        parentId: 'tx_99',
        rootId: 'tx_0',
      );
      txs.add(finalLeaf);

      // Share is 300 / 800 = 37.5%, effective principal = 800 * 37.5% = 300
      // Compounded profit/loss = 1043.85 - 300 = 743.85
      expect(TransactionsHelper.getCloseTargetParent(finalLeaf, txs: txs)?.tid, 'tx_0');
      expect(calc.totalCompoundedProfitLoss(finalLeaf, txs: txs), _d('743.85'));
    });

    test('handles non-terminating fractions (1/3 splits) cleanly with scale 18', () {
      // root (COIN 1 -> COIN 2, rrAmount: 900)
      //  └── step1 (COIN 2 -> COIN 3, srAmount: 300, rrAmount: 450) [300/900 = 1/3 = 33.333333333333333333%]
      //       └── leaf (COIN 3 -> COIN 2, srAmount: 450, rrAmount: 510.75, balance: 510.75) [closes to root]
      // Effective principal: 900 * (33.333333333333333333 / 100) = 299.999999999999999997
      // Profit/Loss: 510.75 - 299.999999999999999997 = 210.750000000000000003
      final root = _tx(id: 'root', srAmount: '900', rrAmount: '900', balance: '600', srId: 1, rrId: 2, parentId: '0', rootId: '0');
      final step1 = _tx(id: 'step1', srAmount: '300', rrAmount: '450', balance: '0', srId: 2, rrId: 3, parentId: 'root', rootId: 'root');
      final leaf = _tx(
        id: 'leaf',
        srAmount: '450',
        rrAmount: '510.75',
        balance: '510.75',
        srId: 3,
        rrId: 2,
        parentId: 'step1',
        rootId: 'root',
      );

      final txs = [root, step1, leaf];
      expect(calc.totalCompoundedProfitLoss(leaf, txs: txs), _d('210.75'));
    });

    test('drills up multi-hop close targets on real ASTER -> SUI partial split chain', () {
      // Real chain (COIN 1 = ASTER, COIN 2 = SUI):
      // tx0 (root): 4197 S -> 8541 A (balance: 8000 A unspent!)
      //  └── tx1: 541 A -> 418 S (balance: 0, inactive) -> TARGET CLOSE as it has the lowest amount
      //       └── tx2 (ceiling close target due to partial tx3): 418 S -> 774.48 A (balance: 0, inactive)
      //            └── tx3: 774.48 A -> 577.346 S
      //                 └── tx4 (2nd hop close target): 417.996 S -> 593.7528 A (balance: 0, inactive) [417.996 / 577.346 = 72.399566291270745791%]
      //                      └── tx5: 593.7528 A -> 449.356 S (balance: 0, inactive)
      //                           └── tx6 (1st hop close target): 449.356 S -> 612.3248 A (balance: 0, inactive)
      //                                └── tx7: 612.3248 A -> 472.5953 S (balance: 0, inactive)
      //                                     └── tx8 (active leaf): 472.5953 S -> 641.0698 A (balance: 641.0698, active)
      const aster = 1;
      const sui = 2;

      final tx0 = _tx(
        id: 'tx0',
        srAmount: '4197',
        rrAmount: '8541',
        balance: '8000',
        srId: sui,
        rrId: aster,
        parentId: '0',
        rootId: '0',
        status: TransactionStatus.partial,
      );
      final tx1 = _tx(
        id: 'tx1',
        srAmount: '541',
        rrAmount: '418',
        balance: '0',
        srId: aster,
        rrId: sui,
        parentId: 'tx0',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx2 = _tx(
        id: 'tx2',
        srAmount: '418',
        rrAmount: '774.48',
        balance: '0',
        srId: sui,
        rrId: aster,
        parentId: 'tx1',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx3 = _tx(
        id: 'tx3',
        srAmount: '774.48',
        rrAmount: '577.346',
        balance: '159.35',
        srId: aster,
        rrId: sui,
        parentId: 'tx2',
        rootId: 'tx0',
        status: TransactionStatus.partial,
      );
      final tx4 = _tx(
        id: 'tx4',
        srAmount: '417.996',
        rrAmount: '593.7528',
        balance: '0',
        srId: sui,
        rrId: aster,
        parentId: 'tx3',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx5 = _tx(
        id: 'tx5',
        srAmount: '593.7528',
        rrAmount: '449.356',
        balance: '0',
        srId: aster,
        rrId: sui,
        parentId: 'tx4',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx6 = _tx(
        id: 'tx6',
        srAmount: '449.356',
        rrAmount: '612.3248',
        balance: '0',
        srId: sui,
        rrId: aster,
        parentId: 'tx5',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx7 = _tx(
        id: 'tx7',
        srAmount: '612.3248',
        rrAmount: '472.5953',
        balance: '0',
        srId: aster,
        rrId: sui,
        parentId: 'tx6',
        rootId: 'tx0',
        status: TransactionStatus.inactive,
      );
      final tx8 = _tx(
        id: 'tx8',
        srAmount: '472.5953',
        rrAmount: '641.0698',
        balance: '641.0698',
        srId: sui,
        rrId: aster,
        parentId: 'tx7',
        rootId: 'tx0',
        status: TransactionStatus.active,
      );

      final txs = [tx0, tx1, tx2, tx3, tx4, tx5, tx6, tx7, tx8];
      final txsMap = {for (final tx in txs) tx.tid: tx};

      final hop1 = TransactionsHelper.getCloseTargetParent(tx8, txsMap: txsMap);
      expect(hop1?.tid, 'tx0');

      final hop2 = TransactionsHelper.getCloseTargetParent(hop1!, txsMap: txsMap);
      expect(hop2?.tid, null);
      expect(calc.totalCompoundedProfitLoss(tx8, txsMap: txsMap), _d('249.388146364225265763'));
    });
  });
}
