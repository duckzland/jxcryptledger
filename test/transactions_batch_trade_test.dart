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
  TransactionStatus status = TransactionStatus.active,
}) {
  return TransactionsModel(
    tid: id,
    rid: '0',
    pid: '0',
    srAmount: _d('100'),
    srId: 1,
    rrAmount: _d(rrAmount),
    rrId: 2,
    balance: _d(balance),
    status: status.index,
    closable: true,
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
  var _nextId = 0;

  @override
  String generateId() => 'child-${++_nextId}';

  @override
  Future<void> add(TransactionsModel tx) async {
    children.add(tx);
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

  Future<void> pumpTrade(WidgetTester tester, List<TransactionsModel> txs) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
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
    await tester.tap(coinField);
    await tester.enterText(coinField, 'USD');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD (#3)'));
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
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '100', balance: '120'), _tx(id: 'b', rrAmount: '100', balance: '130')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox && widget.value == false));
    await tester.pumpAndSettle();
    await enterField(tester, 'Amount', '1000', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(2));
    expect(transactions.children[0].srAmount, _d('20'));
    expect(transactions.children[0].rrAmount, _d('400'));
    expect(transactions.children[1].srAmount, _d('30'));
    expect(transactions.children[1].rrAmount, _d('600'));
  });

  testWidgets('Profit mode skips transactions without positive profit', (tester) async {
    await pumpTrade(tester, [_tx(id: 'profit', rrAmount: '100', balance: '120'), _tx(id: 'flat', rrAmount: '100', balance: '100')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox && widget.value == false));
    await tester.pumpAndSettle();
    await enterField(tester, 'Amount', '500', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'profit');
    expect(transactions.children.single.srAmount, _d('20'));
    expect(transactions.children.single.rrAmount, _d('500'));
  });

  testWidgets('Profit mode refreshes From amount and saves only checked transaction rows', (tester) async {
    await pumpTrade(tester, [_tx(id: 'a', rrAmount: '100', balance: '120'), _tx(id: 'b', rrAmount: '100', balance: '130')]);
    await chooseTargetCoin(tester);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byWidgetPredicate((widget) => widget is Checkbox && widget.value == false));
    await tester.pumpAndSettle();
    expect(amountFieldValue(tester), '50');

    await deselectSecondTransaction(tester);
    expect(amountFieldValue(tester), '20');
    await enterField(tester, 'Amount', '1000', index: 1);
    await confirmTrade(tester);

    expect(transactions.children, hasLength(1));
    expect(transactions.children.single.pid, 'a');
    expect(transactions.children.single.srAmount, _d('20'));
    expect(transactions.children.single.rrAmount, _d('1000'));
  });

  testWidgets('Take profit is unavailable when no selected transaction is profitable', (tester) async {
    await pumpTrade(tester, [_tx(id: 'flat', rrAmount: '100', balance: '100'), _tx(id: 'loss', rrAmount: '100', balance: '90')]);
    await tester.tap(find.byTooltip('Show custom balance'));
    await tester.pumpAndSettle();

    expect(find.text('Take profit'), findsNothing);
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
