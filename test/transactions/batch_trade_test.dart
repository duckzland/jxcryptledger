import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jxledger/app/router.dart';
import 'package:jxledger/features/cryptos/controller.dart';
import 'package:jxledger/features/cryptos/model.dart';
import 'package:jxledger/features/rates/controller.dart';
import 'package:jxledger/features/transactions/controller.dart';
import 'package:jxledger/features/transactions/dialogs/batch_trade.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/system/settings/states.dart';

Decimal _d(String value) => Decimal.parse(value);

TransactionsModel _tx({
  required String id,
  required String rrAmount,
  required String balance,
  String srAmount = '100',
  int srId = 2,
  int rrId = 1,
  String pid = '0',
  String rid = '0',
  TransactionStatus status = TransactionStatus.active,
  bool closable = true,
}) {
  return TransactionsModel(
    tid: id,
    rid: rid,
    pid: pid,
    srAmount: _d(srAmount),
    srId: srId,
    rrAmount: _d(rrAmount),
    rrId: rrId,
    balance: _d(balance),
    status: status.index,
    closable: closable,
    timestamp: DateTime.now().toUtc().microsecondsSinceEpoch - 1000,
    meta: {},
  );
}

class _TestCryptosController extends ChangeNotifier implements CryptosController {
  final cryptos = [
    CryptosModel(id: 1, name: 'Source Coin', symbol: 'SRC', status: 1, active: 1),
    CryptosModel(id: 2, name: 'Result Coin', symbol: 'RES', status: 1, active: 1),
    CryptosModel(id: 3, name: 'Target Coin', symbol: 'USD', status: 1, active: 1),
  ];

  @override
  String? getSymbol(int id) => cryptos.where((crypto) => crypto.id == id).firstOrNull?.symbol;

  @override
  List<CryptosModel> filter(String query) => cryptos.where((crypto) => crypto.searchKey.contains(query)).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestRatesController extends ChangeNotifier implements RatesController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTransactionsController extends ChangeNotifier implements TransactionsController {
  final children = <TransactionsModel>[];
  final closed = <TransactionsModel>[];
  final Map<String, TransactionsModel> indexed = {};
  var _nextId = 0;

  @override
  Map<String, TransactionsModel> getIndexedMap() => indexed;

  @override
  Map<String, List<TransactionsModel>> getIndexedParentMap() {
    final map = <String, List<TransactionsModel>>{};
    for (final tx in indexed.values) {
      if (tx.pid.isNotEmpty && tx.pid != '0') {
        (map[tx.pid] ??= []).add(tx);
      }
    }
    return map;
  }

  @override
  Map<String, Map<String, TransactionsModel>> getIndexedRootMap() {
    final map = <String, Map<String, TransactionsModel>>{};
    for (final tx in indexed.values) {
      final treeKey = tx.isRoot ? tx.tid : tx.rid;
      (map[treeKey] ??= {})[tx.tid] = tx;
    }
    return map;
  }

  @override
  String generateId() => 'child-${++_nextId}';

  @override
  Future<void> add(TransactionsModel tx) async {
    children.add(tx);
    indexed[tx.tid] = tx;
    notifyListeners();
  }

  @override
  Future<String> close(TransactionsModel tx, {bool? silent}) async {
    closed.add(tx);
    indexed[tx.tid] = tx.copyWith(balance: Decimal.zero, status: TransactionStatus.closed.index);
    notifyListeners();
    return tx.uuid;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestStateController implements StateController {
  final values = <String, dynamic>{};

  @override
  dynamic get(String key, {dynamic defaultValue}) => values[key] ?? defaultValue;

  @override
  void set(String key, dynamic value) => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final locator = GetIt.instance;
  late _TestCryptosController cryptos;
  late _TestRatesController rates;
  late _TestTransactionsController transactions;

  ({List<TransactionsModel> tree, TransactionsModel leaf, TransactionsModel flat}) buildSaneProfitTree() {
    const aster = 1;
    const sui = 2;

    final tx0 = _tx(
      id: 'tx0',
      srAmount: '4197',
      rrAmount: '8541',
      balance: '8000',
      srId: sui,
      rrId: aster,
      pid: '0',
      rid: '0',
      status: TransactionStatus.partial,
    );
    final tx1 = _tx(
      id: 'tx1',
      srAmount: '541',
      rrAmount: '418',
      balance: '0',
      srId: aster,
      rrId: sui,
      pid: 'tx0',
      rid: 'tx0',
      status: TransactionStatus.inactive,
      closable: false,
    );
    final tx2 = _tx(
      id: 'tx2',
      srAmount: '418',
      rrAmount: '774.48',
      balance: '0',
      srId: sui,
      rrId: aster,
      pid: 'tx1',
      rid: 'tx0',
      status: TransactionStatus.inactive,
    );
    final tx3 = _tx(
      id: 'tx3',
      srAmount: '774.48',
      rrAmount: '577.346',
      balance: '159.35',
      srId: aster,
      rrId: sui,
      pid: 'tx2',
      rid: 'tx0',
      status: TransactionStatus.partial,
      closable: false,
    );
    final tx4 = _tx(
      id: 'tx4',
      srAmount: '417.996',
      rrAmount: '593.7528',
      balance: '0',
      srId: sui,
      rrId: aster,
      pid: 'tx3',
      rid: 'tx0',
      status: TransactionStatus.inactive,
    );
    final tx5 = _tx(
      id: 'tx5',
      srAmount: '593.7528',
      rrAmount: '449.356',
      balance: '0',
      srId: aster,
      rrId: sui,
      pid: 'tx4',
      rid: 'tx0',
      status: TransactionStatus.inactive,
      closable: false,
    );
    final tx6 = _tx(
      id: 'tx6',
      srAmount: '449.356',
      rrAmount: '612.3248',
      balance: '0',
      srId: sui,
      rrId: aster,
      pid: 'tx5',
      rid: 'tx0',
      status: TransactionStatus.inactive,
    );
    final tx7 = _tx(
      id: 'tx7',
      srAmount: '612.3248',
      rrAmount: '472.5953',
      balance: '0',
      srId: aster,
      rrId: sui,
      pid: 'tx6',
      rid: 'tx0',
      status: TransactionStatus.inactive,
      closable: false,
    );
    final tx8 = _tx(
      id: 'tx8',
      srAmount: '472.5953',
      rrAmount: '641.0698',
      balance: '641.0698',
      srId: sui,
      rrId: aster,
      pid: 'tx7',
      rid: 'tx0',
      status: TransactionStatus.active,
    );
    final flat = _tx(
      id: 'flat',
      srAmount: '100',
      rrAmount: '100',
      balance: '100',
      srId: sui,
      rrId: aster,
      pid: '0',
      rid: '0',
      status: TransactionStatus.active,
    );

    return (tree: [tx0, tx1, tx2, tx3, tx4, tx5, tx6, tx7, tx8], leaf: tx8, flat: flat);
  }

  ({List<TransactionsModel> tree, TransactionsModel leaf}) buildProfitChain({
    required String prefix,
    required String principal,
    required String finalBalance,
  }) {
    const aster = 1;
    const sui = 2;

    final rootBalance = (Decimal.parse('8541') - Decimal.parse(principal)).toString();

    final root = _tx(
      id: '${prefix}_root',
      srAmount: '4197',
      rrAmount: '8541',
      balance: rootBalance, // 8541 - 100 = 8441 (exact remaining balance!)
      srId: sui,
      rrId: aster,
      pid: '0',
      rid: '0',
      status: TransactionStatus.partial,
    );
    final mid = _tx(
      id: '${prefix}_mid',
      srAmount: principal, // 100 ASTER spent from root
      rrAmount: '50', // 50 SUI received
      balance: '0',
      srId: aster,
      rrId: sui,
      pid: '${prefix}_root',
      rid: '${prefix}_root',
      status: TransactionStatus.inactive,
      closable: false,
    );
    final leaf = _tx(
      id: prefix,
      srAmount: '50', // 50 SUI spent (100% of mid)
      rrAmount: finalBalance, // 120 or 130 ASTER received
      balance: finalBalance, // 120 or 130 ASTER available
      srId: sui,
      rrId: aster,
      pid: '${prefix}_mid',
      rid: '${prefix}_root',
      status: TransactionStatus.active,
    );

    return (tree: [root, mid, leaf], leaf: leaf);
  }

  setUp(() async {
    await locator.reset();
    cryptos = _TestCryptosController();
    rates = _TestRatesController();
    transactions = _TestTransactionsController();
    locator.registerSingleton<CryptosController>(cryptos);
    locator.registerSingleton<RatesController>(rates);
    locator.registerSingleton<TransactionsController>(transactions);
    locator.registerSingleton<StateController>(_TestStateController());
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpTrade(WidgetTester tester, List<TransactionsModel> txs, {List<TransactionsModel> extraTxs = const []}) async {
    transactions.indexed
      ..clear()
      ..addAll({
        for (final tx in [...extraTxs, ...txs]) tx.tid: tx,
      });

    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: ThemeData(fontFamily: 'Inter'),
        home: Scaffold(
          body: TransactionsDialogsBatchTrade(srId: 1, transactions: txs, onSave: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseTargetCoin(WidgetTester tester) async {
    final coinDecorator = find.byWidgetPredicate((widget) => widget is InputDecorator && widget.decoration.labelText == 'Coin');
    final coinField = find.ancestor(of: coinDecorator, matching: find.byType(TextField)).first;
    await tester.ensureVisible(coinField);
    await tester.tap(coinField);
    await tester.enterText(coinField, 'USD');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final option = find.text('USD (#3)');
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
  }

  Future<void> enterField(WidgetTester tester, String label, String value, {int index = 0}) async {
    final fields = find.byWidgetPredicate((widget) => widget is InputDecorator && widget.decoration.labelText == label);
    final field = find.ancestor(of: fields.at(index), matching: find.byType(TextField)).first;
    await tester.enterText(field, value);
    await tester.pump(const Duration(milliseconds: 150));
  }

  Future<void> deselectSecondTransaction(WidgetTester tester) async {
    final checkboxes = find.byType(Checkbox);
    await tester.tap(checkboxes.last);
    await tester.pumpAndSettle();
  }

  String amountFieldValue(WidgetTester tester, {int index = 0}) {
    final fields = find.byWidgetPredicate((widget) => widget is InputDecorator && widget.decoration.labelText == 'Amount');
    final field = find.ancestor(of: fields.at(index), matching: find.byType(TextField)).first;
    return tester.widget<TextField>(field).controller!.text;
  }

  Future<void> confirmTrade(WidgetTester tester) async {
    await tester.tap(find.text('Trade').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trade').last);
    await tester.pumpAndSettle();
  }

  testWidgets('Rate mode multiplies each selected transaction balance by the rate', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '20', balance: '20'), _tx(id: 'b', rrAmount: '30', balance: '30')]);
    await chooseTargetCoin(tester);
    await enterField(tester, 'Rate', '2');
    await confirmTrade(tester);

    expect(transactions.children, hasLength(2));
    expect(transactions.children[0].srAmount, _d('20'));
    expect(transactions.children[0].rrAmount, _d('40'));
    expect(transactions.children[1].srAmount, _d('30'));
    expect(transactions.children[1].rrAmount, _d('60'));
  });

  testWidgets('Balance mode spreads source and target totals by transaction balance', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '50', balance: '50'), _tx(id: 'b', rrAmount: '150', balance: '150')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Amount', '300', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(2));
    expect(transactions.children[0].srAmount, _d('50'));
    expect(transactions.children[0].rrAmount, _d('75'));
    expect(transactions.children[1].srAmount, _d('150'));
    expect(transactions.children[1].rrAmount, _d('225'));
  });

  testWidgets('Rate mode saves only checked transaction rows', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '20', balance: '20'), _tx(id: 'b', rrAmount: '30', balance: '30')]);
    await chooseTargetCoin(tester);
    await enterField(tester, 'Rate', '2');
    await deselectSecondTransaction(tester);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'a');
    expect(transactions.children.single.rrAmount, _d('40'));
  });

  testWidgets('Balance mode spreads totals over checked transaction rows only', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '50', balance: '50'), _tx(id: 'b', rrAmount: '150', balance: '150')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await deselectSecondTransaction(tester);
    await enterField(tester, 'Amount', '50');
    await enterField(tester, 'Amount', '120', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'a');
    expect(transactions.children.single.srAmount, _d('50'));
    expect(transactions.children.single.rrAmount, _d('120'));
  });

  testWidgets('Profit mode values each transaction by its share of total SOL profit', (tester) async {
    final chainA = buildProfitChain(prefix: 'a', principal: '100', finalBalance: '120'); // profit = 20
    final chainB = buildProfitChain(prefix: 'b', principal: '100', finalBalance: '130'); // profit = 30

    await pumpTrade(tester, [chainA.leaf, chainB.leaf], extraTxs: [...chainA.tree, ...chainB.tree]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Amount', '1000', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(2));
    expect(transactions.children[0].srAmount, _d('20'));
    expect(transactions.children[0].rrAmount, _d('400'));
    expect(transactions.children[1].srAmount, _d('30'));
    expect(transactions.children[1].rrAmount, _d('600'));
  });

  testWidgets('Profit mode accepts a custom source amount and consumes profits in row order', (tester) async {
    final chainA = buildProfitChain(prefix: 'a', principal: '100', finalBalance: '120'); // profit = 20
    final chainB = buildProfitChain(prefix: 'b', principal: '100', finalBalance: '130'); // profit = 30

    await pumpTrade(tester, [chainA.leaf, chainB.leaf], extraTxs: [...chainA.tree, ...chainB.tree]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();

    expect(amountFieldValue(tester), '');
    await enterField(tester, 'Amount', '35');
    await enterField(tester, 'Amount', '700', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(2));
    expect(transactions.children[0].srAmount, _d('14'));
    expect(transactions.children[0].rrAmount, _d('280'));
    expect(transactions.children[1].srAmount, _d('21'));
    expect(transactions.children[1].rrAmount, _d('420'));
  });

  testWidgets('Profit mode rejects a custom source amount above selected profit', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '100', balance: '120'), _tx(id: 'b', rrAmount: '100', balance: '130')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox && widget.value == false));
    await tester.pumpAndSettle();

    await enterField(tester, 'Amount', '51');
    await enterField(tester, 'Amount', '700', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, isEmpty);
  });

  testWidgets('Profit mode skips transactions without positive profit', (tester) async {
    final profitChain = buildProfitChain(prefix: 'profit', principal: '100', finalBalance: '120'); // profit = 20
    final flat = _tx(id: 'flat', rrAmount: '100', balance: '100');

    await pumpTrade(tester, [profitChain.leaf, flat], extraTxs: profitChain.tree);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();

    await enterField(tester, 'Amount', '500', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'profit_root');
    expect(transactions.children.single.srAmount, _d('20'));
    expect(transactions.children.single.rrAmount, _d('500'));
  });

  testWidgets('Profit mode uses selected profit max and saves only checked transaction rows', (tester) async {
    final chainA = buildProfitChain(prefix: 'a', principal: '100', finalBalance: '120'); // profit = 20
    final chainB = buildProfitChain(prefix: 'b', principal: '100', finalBalance: '130'); // profit = 30

    await pumpTrade(tester, [chainA.leaf, chainB.leaf], extraTxs: [...chainA.tree, ...chainB.tree]);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();
    expect(amountFieldValue(tester), '');

    await deselectSecondTransaction(tester);
    expect(amountFieldValue(tester), '');

    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();
    expect(amountFieldValue(tester), '20');

    await chooseTargetCoin(tester);

    await chooseTargetCoin(tester);
    await enterField(tester, 'Amount', '1000', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'a_root');
    expect(transactions.children.single.srAmount, _d('20'));
    expect(transactions.children.single.rrAmount, _d('1000'));
  });

  testWidgets('Take profit is unavailable when no selected transaction is profitable', (tester) async {
    await pumpTrade(tester, [_tx(id: 'flat', rrAmount: '100', balance: '100'), _tx(id: 'loss', rrAmount: '100', balance: '90')]);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();

    expect(find.text('Take profit'), findsNothing);
  });

  testWidgets('From max returns to available balance when selected profit disappears', (tester) async {
    final data = buildSaneProfitTree();
    await pumpTrade(tester, [data.flat, data.leaf], extraTxs: data.tree);

    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();
    expect(amountFieldValue(tester), '');

    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();

    // Closes to tx0 (root): 641.0698 - (541 * (417.996 / 577.346)) = 249.388146364225265763
    expect(amountFieldValue(tester), '249.388146364225265763');

    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use maximum amount'));
    await tester.pumpAndSettle();

    expect(amountFieldValue(tester), '641.0698');
  });

  testWidgets('zero rate does not save children', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '20', balance: '20')]);
    await chooseTargetCoin(tester);
    await enterField(tester, 'Rate', '0');
    await confirmTrade(tester);

    expect(transactions.children, isEmpty);
  });

  testWidgets('zero To amount does not save in Balance mode', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '20', balance: '20')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Amount', '0', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, isEmpty);
  });
}
