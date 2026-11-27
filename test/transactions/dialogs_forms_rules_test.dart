import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:jxledger/app/exceptions.dart';
import 'package:jxledger/app/router.dart';
import 'package:jxledger/features/cryptos/controller.dart';
import 'package:jxledger/features/cryptos/model.dart';
import 'package:jxledger/features/rates/controller.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/controller.dart';
import 'package:jxledger/features/transactions/dialogs/batch_action.dart';
import 'package:jxledger/features/transactions/dialogs/batch_edit.dart';
import 'package:jxledger/features/transactions/dialogs/details.dart';
import 'package:jxledger/features/transactions/forms/create.dart';
import 'package:jxledger/features/transactions/forms/edit.dart';
import 'package:jxledger/features/transactions/forms/trade.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/repository.dart';
import 'package:jxledger/features/transactions/widgets/status_text.dart';
import 'package:jxledger/system/settings/states.dart';

import '../faker/hive.dart';

Decimal _d(String value) => Decimal.parse(value);

TransactionsModel _tx({
  required String id,
  String pid = '0',
  String rid = '0',
  int srId = 1,
  int rrId = 2,
  String srAmount = '100',
  String rrAmount = '100',
  String balance = '100',
  TransactionStatus status = TransactionStatus.active,
  bool closable = true,
  Map<String, dynamic>? meta,
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
    meta: meta ?? {},
  );
}

class _TestCryptosController extends ChangeNotifier implements CryptosController {
  final cryptos = [
    CryptosModel(id: 1, name: 'Source Coin', symbol: 'SRC', status: 1, active: 1),
    CryptosModel(id: 2, name: 'Result Coin', symbol: 'RES', status: 1, active: 1),
  ];

  @override
  String? getSymbol(int id) => cryptos.where((crypto) => crypto.id == id).firstOrNull?.symbol;

  @override
  CryptosModel? get(String id) => cryptos.where((crypto) => crypto.id.toString() == id).firstOrNull;

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
  final added = <TransactionsModel>[];
  final updated = <TransactionsModel>[];
  final closed = <TransactionsModel>[];
  final indexed = <String, TransactionsModel>{};
  var _nextId = 0;

  @override
  String generateId() => 'tx-${++_nextId}';

  @override
  Future<void> add(TransactionsModel tx) async {
    added.add(tx);
    indexed[tx.tid] = tx;
    notifyListeners();
  }

  @override
  Future<void> update(TransactionsModel tx) async {
    updated.add(tx);
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
  bool hasLeaf(TransactionsModel tx) => false;

  @override
  bool isUpdatable(TransactionsModel tx) => true;

  @override
  bool isClosable(TransactionsModel tx) => true;

  @override
  bool isFinalizable(TransactionsModel tx) => true;

  @override
  bool isDeletable(TransactionsModel tx) => true;

  @override
  bool isRefundable(TransactionsModel tx) => true;

  @override
  TransactionsModel? getRoot(TransactionsModel tx) => indexed[tx.rid];

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
  List<TransactionsModel> collectBranchWithTarget(TransactionsModel target) => indexed[target.tid] == null ? const [] : [target];

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
  TestWidgetsFlutterBinding.ensureInitialized();

  final locator = GetIt.instance;
  late _TestCryptosController cryptos;
  late _TestTransactionsController transactions;

  setUpAll(() {
    Hive.init('./test/database');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionsAdapter());
    }
  });

  setUp(() async {
    await locator.reset();
    cryptos = _TestCryptosController();
    transactions = _TestTransactionsController();
    locator.registerSingleton<CryptosController>(cryptos);
    locator.registerSingleton<RatesController>(_TestRatesController());
    locator.registerSingleton<TransactionsController>(transactions);
    locator.registerSingleton<StateController>(_TestStateController());
  });

  tearDown(() async {
    await locator.reset();
  });

  Future<void> pumpDialog(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseCoin(WidgetTester tester, String coin, {int index = 0}) async {
    final coinDecorators = find.byWidgetPredicate((widget) => widget is InputDecorator && widget.decoration.labelText == 'Coin');
    final field = find.ancestor(of: coinDecorators.at(index), matching: find.byType(TextField)).first;
    await tester.tap(field);
    await tester.enterText(field, coin);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$coin (#${coin == 'SRC' ? 1 : 2})'));
    await tester.pumpAndSettle();
  }

  Future<void> enterAmount(WidgetTester tester, String value, {int index = 0}) async {
    final fields = find.byWidgetPredicate((widget) => widget is InputDecorator && widget.decoration.labelText == 'Amount');
    final field = find.ancestor(of: fields.at(index), matching: find.byType(TextField)).first;
    await tester.enterText(field, value);
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('Create form saves a normal transaction and validates source/target coin selection', (tester) async {
    await pumpDialog(tester, TransactionFormCreate(onSave: (_, _) {}));

    await enterAmount(tester, '100');
    await chooseCoin(tester, 'SRC');
    await enterAmount(tester, '125', index: 1);
    await chooseCoin(tester, 'RES', index: 1);
    await tester.tap(find.text('Create New'));
    await tester.pumpAndSettle();

    expect(transactions.added, hasLength(1));
    expect(transactions.added.single.srAmount, _d('100'));
    expect(transactions.added.single.rrAmount, _d('125'));
    expect(transactions.added.single.srId, 1);
    expect(transactions.added.single.rrId, 2);
  });

  testWidgets('Create form converts a transaction to capital when selected', (tester) async {
    await pumpDialog(tester, TransactionFormCreate(onSave: (_, _) {}));

    await enterAmount(tester, '75');
    await chooseCoin(tester, 'SRC');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create New'));
    await tester.pumpAndSettle();

    expect(transactions.added, hasLength(1));
    expect(transactions.added.single.isCapital, isTrue);
    expect(transactions.added.single.rrAmount, _d('75'));
    expect(transactions.added.single.srId, 1);
  });

  testWidgets('Trade form saves a child transaction with the selected target coin', (tester) async {
    final parent = _tx(id: 'parent', rid: '0', pid: '0', rrId: 1, rrAmount: '100', balance: '100');
    await pumpDialog(tester, TransactionFormTrade(initialData: parent, onSave: (_, _) {}));

    await enterAmount(tester, '25');
    await enterAmount(tester, '30', index: 1);
    await chooseCoin(tester, 'RES');
    await tester.tap(find.text('Trade'));
    await tester.pumpAndSettle();

    expect(transactions.added, hasLength(1));
    expect(transactions.added.single.pid, 'parent');
    expect(transactions.added.single.srAmount, _d('25'));
    expect(transactions.added.single.rrAmount, _d('30'));
  });

  testWidgets('Edit form exposes initial values and updates a transaction', (tester) async {
    final tx = _tx(id: 'edit-me', rid: '0', pid: '0', meta: {'purchase_notes': 'Existing note'});
    await pumpDialog(tester, TransactionFormEdit(initialData: tx, onSave: (_, _) {}));

    expect(find.text('Edit Transaction'), findsOneWidget);
    expect(find.text('100'), findsWidgets);
    await enterAmount(tester, '110');
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();

    expect(transactions.updated, hasLength(1));
    expect(transactions.updated.single.srAmount, _d('110'));
  });

  testWidgets('Empty batch edit and batch action dialogs show their empty states', (tester) async {
    await pumpDialog(tester, TransactionsDialogsBatchEdit(transactions: const [], onSave: (_) {}));
    expect(find.text('No transactions to edit'), findsOneWidget);

    await pumpDialog(
      tester,
      TransactionsDialogsBatchAction(transactions: const [], mode: TransactionsBatchActionMode.close, onSave: (_) {}),
    );
    expect(find.text('No transactions to close'), findsOneWidget);
  });

  testWidgets('Transaction details renders information and close action', (tester) async {
    final tx = _tx(id: 'details', rid: '0', pid: '0', meta: {'purchase_notes': 'Test purchase note'});
    transactions.indexed[tx.tid] = tx;

    await pumpDialog(tester, TransactionsDialogsDetails(tx: tx));

    expect(find.text('Transaction Information'), findsOneWidget);
    expect(find.text('Test purchase note'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets('Status widget renders every transaction status', (tester) async {
    await pumpDialog(tester, Column(children: [for (final status in TransactionStatus.values) TransactionsWidgetsStatusText(status)]));

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Finalized'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
  });

  group('Transaction rule gates', () {
    late TransactionsRepository repo;
    late Box<TransactionsModel> box;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_rules_comprehensive_test');
      await box.clear();
      repo = TransactionsRepository();
      repo.box = HiveBoxFaker<TransactionsModel>('transactions_rules_comprehensive_test', hiveBoxOverride: box);
      repo.boxNameDefault = 'transactions_rules_comprehensive_test';
    });

    tearDown(() async {
      await box.clear();
    });

    test('create rule accepts a valid root and rejects a mismatched root balance', () async {
      final valid = _tx(id: 'root', srAmount: '100', rrAmount: '100', balance: '100');
      await repo.add(valid);
      expect(repo.get('root'), valid);

      final mismatch = valid.copyWith(tid: 'mismatch', balance: _d('90'));
      expect(
        () => repo.canAdd(mismatch),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txAddRootBalanceMismatch)),
      );
    });

    test('trade rule rejects missing, invalid-state, and zero-balance originals', () async {
      final missing = _tx(id: 'missing', pid: 'missing', rid: 'missing');
      expect(
        () => repo.canTrade(missing),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txTradeNotFound)),
      );

      final closed = _tx(id: 'closed', rid: '0', pid: '0', status: TransactionStatus.closed);
      await repo.box.put(closed.tid, closed);
      repo.resetIndexes();
      expect(
        () => repo.canTrade(closed),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txTradeInvalidState)),
      );

      final zero = _tx(id: 'zero', rid: '0', pid: '0', balance: '0');
      await repo.box.put(zero.tid, zero);
      repo.resetIndexes();
      expect(
        () => repo.canTrade(zero),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txTradeInvalidBalance)),
      );
    });

    test('close, finalize, refund, and delete rule surfaces reject invalid state', () async {
      final root = _tx(id: 'rule-root', rid: '0', pid: '0');
      await box.put(root.tid, root);

      expect(
        () => repo.canClose(root),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txCloseNotLeaf)),
      );
      expect(() => repo.canFinalize(root), returnsNormally);
      expect(
        () => repo.canRefund(root),
        throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txRefundRootClosed)),
      );
      expect(() => repo.canDelete(root), returnsNormally);
    });
  });
}
