import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive_ce.dart';

import 'package:jxledger/features/cryptos/controller.dart';
import 'package:jxledger/features/rates/controller.dart';
import 'package:jxledger/features/rates/model.dart';
import 'package:jxledger/features/rates/repository.dart';
import 'package:jxledger/features/rates/service.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/controller.dart';
import 'package:jxledger/features/transactions/screens/active.dart';
import 'package:jxledger/features/transactions/screens/finalized.dart';
import 'package:jxledger/features/transactions/screens/history.dart';
import 'package:jxledger/features/transactions/screens/journal.dart';
import 'package:jxledger/features/transactions/screens/overview.dart';
import 'package:jxledger/features/transactions/mixins/actions.dart';
import 'package:jxledger/features/transactions/mixins/flags.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/page.dart';
import 'package:jxledger/features/transactions/repository.dart';
import 'package:jxledger/features/transactions/service.dart';
import 'package:jxledger/features/transactions/widgets/panel_item.dart';
import 'package:jxledger/features/transactions/widgets/status_text.dart';
import 'package:jxledger/ipc/client.dart';
import 'package:jxledger/ipc/server.dart';
import 'package:jxledger/system/settings/repository.dart';
import 'package:jxledger/system/settings/states.dart';

import '../faker/hive.dart';
import '../faker/ipc/client.dart';

Decimal d(String value) => Decimal.parse(value);

TransactionsModel tx({
  String tid = 'tx',
  String pid = '0',
  String rid = '0',
  int srId = 1,
  int rrId = 1,
  String srAmount = '100',
  String rrAmount = '100',
  String balance = '100',
  TransactionStatus status = TransactionStatus.active,
  bool closable = true,
  Map<String, dynamic>? meta,
}) {
  return TransactionsModel(
    tid: tid,
    rid: rid,
    pid: pid,
    srAmount: d(srAmount),
    srId: srId,
    rrAmount: d(rrAmount),
    rrId: rrId,
    balance: d(balance),
    status: status.index,
    closable: closable,
    timestamp: DateTime.now().toUtc().microsecondsSinceEpoch - 1000,
    meta: meta ?? const {},
  );
}

class _TestRatesController extends ChangeNotifier implements RatesController {
  @override
  void updateNeedRates() {}

  @override
  void addQueue(int sourceId, int targetId, {bool force = true}) {}

  @override
  Decimal getStoredRate(int sourceId, int targetId, {bool throwable = false}) =>
      Decimal.one;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestStateController implements StateController {
  final values = <String, dynamic>{};

  @override
  dynamic get(String key, {dynamic defaultValue}) =>
      values[key] ?? defaultValue;

  @override
  void set(String key, dynamic value) => values[key] = value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestCryptosController extends ChangeNotifier
    implements CryptosController {
  @override
  final bool hasCryptos;

  _TestCryptosController({this.hasCryptos = true});

  @override
  bool isEmpty() => !hasCryptos;

  @override
  bool isNotEmpty() => hasCryptos;

  @override
  String? getSymbol(int id) => 'Coin $id';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTransactionsController extends ChangeNotifier
    implements TransactionsController {
  @override
  List<TransactionsModel> get items => const [];

  @override
  bool hasDeletableRoot() => false;

  @override
  bool hasClosableLeaf() => false;

  @override
  bool hasFinalizable() => false;

  @override
  bool isEqualToItems(List<TransactionsModel> other) => other.isEmpty;

  @override
  bool isEmpty() => true;

  @override
  Future<String> exportDatabase() async => '[]';

  @override
  Future<void> importDatabase(String json) async {}

  @override
  Future<bool> wipe() async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ActionsHarness with TransactionsMixinsActions {}

class _FlagsHarness with TransactionsMixinsFlags {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final locator = GetIt.instance;

  setUpAll(() {
    Hive.init('./test/database');
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TransactionsAdapter());
    }
  });

  setUp(() async {
    await locator.reset();
  });

  tearDown(() async {
    await locator.reset();
  });

  group('TransactionsModel', () {
    test(
      'copy, JSON, map and derived properties preserve transaction data',
      () {
        final original = tx(
          tid: 'root',
          srId: 1,
          rrId: 1,
          meta: {'group_notes': 'test'},
        );
        final copied = original.copyWith(
          balance: d('75'),
          status: TransactionStatus.partial.index,
        );

        expect(copied.tid, 'root');
        expect(copied.balance, d('75'));
        expect(copied.statusEnum, TransactionStatus.partial);
        expect(copied.isRoot, isTrue);
        expect(copied.isCapital, isTrue);
        expect(copied.isPartial, isTrue);
        expect(copied.noteText, 'test');
        expect(copied.rate, Decimal.one);

        final json = copied.toJson();
        expect(TransactionsModel.fromJson(json).toJson(), json);
        expect(TransactionsModel.fromMap(copied.toMap()).uuid, 'root');
      },
    );

    test('status and relationship getters classify leaf transactions', () {
      final leaf = tx(tid: 'leaf', pid: 'root', rid: 'root', srId: 1, rrId: 2);
      expect(leaf.isLeaf, isTrue);
      expect(leaf.hasParent, isTrue);
      expect(leaf.hasRoot, isTrue);
      expect(leaf.isTradable, isTrue);
      expect(leaf.statusText, 'Active');
    });
  });

  group('TransactionsAdapter and repository indexes', () {
    late Box<TransactionsModel> box;
    late TransactionsRepository repository;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_feature_test');
      await box.clear();
      repository = TransactionsRepository();
      repository.box = HiveBoxFaker<TransactionsModel>(
        'transactions_feature_test',
        hiveBoxOverride: box,
      );
      repository.boxNameDefault = 'transactions_feature_test';
    });

    tearDown(() async {
      await box.close();
    });

    test('adapter round-trips precise decimal values and metadata', () async {
      await box.put(
        'precise',
        tx(
          tid: 'precise',
          srId: 1,
          rrId: 2,
          srAmount: '1.123456789012345678',
          rrAmount: '2.123456789012345678',
          balance: '1.75',
          meta: {'group_notes': 'kept'},
        ),
      );

      final stored = box.get('precise')!;
      expect(stored.srAmount, d('1.123456789012345678'));
      expect(stored.rrAmount, d('2.123456789012345678'));
      expect(stored.balance, d('1.75'));
      expect(stored.noteText, 'kept');
    });

    test(
      'indexes and branch collectors cover roots, parents and terminal leaves',
      () async {
        final root = tx(tid: 'root', rrId: 1);
        final parent = tx(
          tid: 'parent',
          pid: 'root',
          rid: 'root',
          srId: 1,
          rrId: 2,
          srAmount: '100',
          rrAmount: '80',
          balance: '80',
        );
        final leaf = tx(
          tid: 'leaf',
          pid: 'parent',
          rid: 'root',
          srId: 2,
          rrId: 3,
          srAmount: '80',
          rrAmount: '90',
          balance: '90',
        );

        await repository.add(root);
        await repository.add(parent);
        await repository.add(leaf);

        expect(
          repository.getIndexedMap().keys,
          containsAll(['root', 'parent', 'leaf']),
        );
        expect(
          repository.getIndexedParentMap()['root']!.map((item) => item.tid),
          contains('parent'),
        );
        expect(
          repository.collectAllRoots().map((item) => item.tid),
          contains('root'),
        );
        expect(
          repository.collectAllTerminalLeaves().map((item) => item.tid),
          contains('leaf'),
        );
        expect(repository.getCapitalBalance(root), d('0'));
      },
    );
  });

  group('TransactionsController, service and action mixins', () {
    late TransactionsRepository repository;
    late Box<TransactionsModel> box;
    late _TestRatesController rates;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>(
        'transactions_feature_controller_test',
      );
      await box.clear();
      repository = TransactionsRepository();
      repository.box = HiveBoxFaker<TransactionsModel>(
        'transactions_feature_controller_test',
        hiveBoxOverride: box,
      );
      repository.boxNameDefault = 'transactions_feature_controller_test';
      rates = _TestRatesController();
      locator.registerSingleton<RatesController>(rates);
      locator.registerSingleton<StateController>(_TestStateController());
      locator.registerSingleton<IpcClient>(IpcClientFaker());
      locator.registerSingleton<IpcServer>(IpcServer());
    });

    tearDown(() async {
      await box.close();
    });

    test('controller loads indexed items and exposes branch helpers', () async {
      await repository.add(tx(tid: 'root'));
      final controller = TransactionsController(repository);
      await controller.init();

      expect(controller.items.map((item) => item.tid), contains('root'));
      expect(controller.generateId(), isNotEmpty);
      expect(controller.collectAllRoots(), isNotEmpty);
      expect(
        controller.isBothEqual(controller.items.first, controller.items.first),
        isTrue,
      );
      expect(controller.isEqualToItems([tx(tid: 'root')]), isFalse);
      controller.dispose();
    });

    test('controller and action mixins calculate available actions', () async {
      final root = tx(tid: 'root');
      await repository.add(root);
      final controller = TransactionsController(repository);
      await controller.init();

      expect(controller.isDeletable(root), isTrue);
      expect(controller.isTradable(root), isTrue);

      final actions = _ActionsHarness();
      actions.txController = controller;
      actions.txs = [root];
      actions.checkForDeletable();
      expect(actions.isDeletable, isTrue);
    });

    test(
      'service forwards repository operations and exposes rate IDs',
      () async {
        final settingsRepository = SettingsRepository();
        final fakeRatesRepository = RatesRepository();
        fakeRatesRepository.box = HiveBoxFaker<RatesModel>(
          'rates_feature_test',
        );
        await fakeRatesRepository.init();

        final ratesService = RatesService(
          fakeRatesRepository,
          settingsRepository,
        );
        locator.registerSingleton<RatesService>(ratesService);

        await repository.add(tx(tid: 'root'));
        final service = TransactionsService(repository);
        await service.init();

        expect(repository.count(), 1);
        expect(service.getAllRateID(), containsAll(['1-1']));
        await service.dispose();
        await ratesService.dispose();
      },
    );
  });

  group('Transactions widgets and page modes', () {
    setUp(() {
      locator.registerSingleton<CryptosController>(_TestCryptosController());
      locator.registerSingleton<TransactionsController>(
        _TestTransactionsController(),
      );
      locator.registerSingleton<RatesController>(_TestRatesController());
      locator.registerSingleton<StateController>(_TestStateController());
    });

    testWidgets('StatusText renders every transaction status', (tester) async {
      for (final status in TransactionStatus.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TransactionsWidgetsStatusText(status)),
          ),
        );
        expect(
          find.text(status.name[0].toUpperCase() + status.name.substring(1)),
          findsOneWidget,
        );
      }
    });

    testWidgets('PanelItem renders title and balance subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TransactionsWidgetsPanelItem(
              title: 'Profit',
              subtitle: '12.50 USD',
              value: 12.5,
            ),
          ),
        ),
      );
      expect(find.text('Profit'), findsOneWidget);
      expect(find.text('+12.50 USD'), findsOneWidget);
    });

    test('page view modes include all transaction screens', () {
      expect(TransactionsViewMode.values.map((mode) => mode.name), [
        'overview',
        'active',
        'journal',
        'history',
        'finalized',
      ]);
    });

    testWidgets('transactions page prompts for crypto data when unavailable', (
      tester,
    ) async {
      await locator.unregister<CryptosController>();
      locator.registerSingleton<CryptosController>(
        _TestCryptosController(hasCryptos: false),
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TransactionsPage())),
      );
      await tester.pump();

      expect(find.text('Cryptocurrency data not available'), findsOneWidget);
      expect(
        find.text(
          'You need to fetch the latest crypto list before adding transactions.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('transactions page shows its empty-database action screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TransactionsPage())),
      );
      await tester.pump();

      expect(find.text('Add Transaction'), findsOneWidget);
      expect(find.text('Add New'), findsOneWidget);
    });

    testWidgets('transaction screens render empty states', (tester) async {
      final commonFlags = <String, Map<TransactionsFlagsType, bool>>{};
      final screens = <Widget>[
        TransactionsActiveView(
          transactions: const [],
          txsFlags: commonFlags,
          filterMode: 0,
          sortMode: 0,
          onStatusChanged: () {},
          panelsAction: '',
        ),
        TransactionsOverviewView(
          transactions: const [],
          txsFlags: commonFlags,
          filterMode: 0,
          sortMode: 0,
          onStatusChanged: () {},
          panelsAction: '',
        ),
        TransactionsJournalView(
          transactions: const [],
          txsFlags: commonFlags,
          filterMode: 0,
          onStatusChanged: () {},
        ),
        TransactionHistory(
          transactions: const [],
          sortMode: 0,
          onStatusChanged: () {},
          panelsAction: '',
          txsFlags: commonFlags,
        ),
        TransactionsFinalizedView(
          transactions: const [],
          txsFlags: commonFlags,
          filterMode: 0,
          onStatusChanged: () {},
          panelsAction: '',
        ),
      ];

      const emptyMessages = [
        'No active transactions available',
        'No active transactions available',
        'No transactions available',
        null,
        'No finalized transactions available',
      ];

      for (var index = 0; index < screens.length; index++) {
        final screen = screens[index];
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
        await tester.pump();
        final message = emptyMessages[index];
        if (message != null) {
          expect(find.text(message), findsOneWidget);
        }
      }
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('flags mixin reads precomputed screen flags', () {
      final flags = _FlagsHarness();
      flags.fxs = {
        'tx': {
          TransactionsFlagsType.tradable: true,
          TransactionsFlagsType.closable: false,
          TransactionsFlagsType.hasLeaf: true,
        },
      };
      expect(flags.fxsIsTradable(tx(tid: 'tx')), isTrue);
      expect(flags.fxsIsClosable(tx(tid: 'tx')), isFalse);
      expect(flags.fxsHasLeaf(tx(tid: 'tx')), isTrue);
    });
  });
}
