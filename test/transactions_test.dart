import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/repository.dart';

void main() async {
  // Initialize Hive in memory for testing
  Hive.init('./test/database');
  Hive.registerAdapter(TransactionsAdapter());

  group('Transactions balance propagation', () {
    late TransactionsRepository repo;
    late Box<TransactionsModel> box;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_test');
      await box.clear();
      repo = TransactionsRepository();
      repo.boxNameDefault = 'transactions_test';
    });

    test('root -> leaf balance decreases correctly', () async {
      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: 100,
        srId: 1,
        rrAmount: 100,
        rrId: 2,
        balance: 100,
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(root);

      final leaf = TransactionsModel(
        tid: 'leaf1',
        rid: 'root',
        pid: 'root',
        srAmount: 40,
        srId: 2,
        rrAmount: 40,
        rrId: 3,
        balance: 40,
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf);

      final updatedRoot = box.get('root')!;
      expect(updatedRoot.balance, 60);
      expect(updatedRoot.statusEnum, TransactionStatus.partial);
    });

    test('root -> leaf -> leaf balance propagates correctly', () async {
      final root = TransactionsModel(
        tid: 'root2',
        rid: '0',
        pid: '0',
        srAmount: 200,
        srId: 1,
        rrAmount: 200,
        rrId: 2,
        balance: 200,
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(root);

      final leaf1 = TransactionsModel(
        tid: 'leaf21',
        rid: 'root2',
        pid: 'root2',
        srAmount: 120,
        srId: 2,
        rrAmount: 120,
        rrId: 3,
        balance: 120,
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf1);

      final leaf2 = TransactionsModel(
        tid: 'leaf22',
        rid: 'root2',
        pid: 'leaf21',
        srAmount: 50,
        srId: 3,
        rrAmount: 50,
        rrId: 2, // This is the same as root to test closable logic
        balance: 50,
        status: TransactionStatus.active.index,
        closable: false, // This is intentionally false to test if it gets updated to true
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf2);

      final updatedRoot = box.get('root2')!;
      expect(updatedRoot.balance, 80); // 200 - 120

      // The root is still partial because leaf21 doesnt use all of its balance
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      final updatedLeaf21 = box.get('leaf21')!;
      expect(updatedLeaf21.balance, 70); // 120 - 50

      // The leaf21 is still partial because leaf22 doesnt use all of its balance
      expect(updatedLeaf21.statusEnum, TransactionStatus.partial);

      final updatedLeaf22 = box.get('leaf22')!;
      expect(updatedLeaf22.balance, 50); // 50

      // Leaf22 is active because it has no children
      expect(updatedLeaf22.statusEnum, TransactionStatus.active);

      // Leaf22 should be closable because its balance coin type is the same as the root [need to make test that drill further than 2 parent]
      expect(updatedLeaf22.closable, true);
    });
  });
  // group('Transactions insane scenarios', () {
  //   late TransactionsRepository repo;
  //   late Box<TransactionsModel> box;

  //   setUp(() async {
  //     box = await Hive.openBox<TransactionsModel>('transactions_insane');
  //     await box.clear();
  //     repo = TransactionsRepository();
  //     repo.boxNameDefault = 'transactions_insane';
  //   });

  //   test('root with many leaves balances correctly', () async {
  //     final root = TransactionsModel(
  //       tid: 'root_many',
  //       rid: '0',
  //       pid: '0',
  //       srAmount: 500,
  //       srId: 1,
  //       rrAmount: 500,
  //       rrId: 2,
  //       balance: 500,
  //       status: TransactionStatus.active.index,
  //       closable: true,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );

  //     await repo.add(root);

  //     // Add multiple leaves
  //     final leafA = TransactionsModel(
  //       tid: 'leafA',
  //       rid: 'root_many',
  //       pid: 'root_many',
  //       srAmount: 100,
  //       srId: 2,
  //       rrAmount: 100,
  //       rrId: 3,
  //       balance: 100,
  //       status: TransactionStatus.active.index,
  //       closable: false,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );
  //     final leafB = leafA.copyWith(tid: 'leafB', srAmount: 150, rrAmount: 150);
  //     final leafC = leafA.copyWith(tid: 'leafC', srAmount: 200, rrAmount: 200);

  //     await repo.add(leafA);
  //     await repo.add(leafB);
  //     await repo.add(leafC);

  //     final updatedRoot = box.get('root_many')!;
  //     expect(updatedRoot.balance, 50); // 500 - (100+150+200)
  //     expect(updatedRoot.statusEnum, TransactionStatus.partial);
  //   });

  //   test('closed leaf does not affect parent balance further', () async {
  //     final root = TransactionsModel(
  //       tid: 'root_closed',
  //       rid: '0',
  //       pid: '0',
  //       srAmount: 300,
  //       srId: 1,
  //       rrAmount: 300,
  //       rrId: 2,
  //       balance: 300,
  //       status: TransactionStatus.active.index,
  //       closable: true,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );

  //     await repo.add(root);

  //     final leaf = TransactionsModel(
  //       tid: 'leaf_closed',
  //       rid: 'root_closed',
  //       pid: 'root_closed',
  //       srAmount: 150,
  //       srId: 2,
  //       rrAmount: 150,
  //       rrId: 3,
  //       balance: 150,
  //       status: TransactionStatus.closed.index, // force closed
  //       closable: true,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );

  //     await repo.add(leaf);

  //     final updatedRoot = box.get('root_closed')!;
  //     // Root balance should still reflect subtraction, but status may flip inactive if fully spent
  //     expect(updatedRoot.balance, 150);
  //     expect(updatedRoot.statusEnum, TransactionStatus.partial);
  //   });

  //   test('mixed leaves (active + closed) propagate correctly', () async {
  //     final root = TransactionsModel(
  //       tid: 'root_mix',
  //       rid: '0',
  //       pid: '0',
  //       srAmount: 400,
  //       srId: 1,
  //       rrAmount: 400,
  //       rrId: 2,
  //       balance: 400,
  //       status: TransactionStatus.active.index,
  //       closable: true,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );

  //     await repo.add(root);

  //     final leafActive = TransactionsModel(
  //       tid: 'leaf_active',
  //       rid: 'root_mix',
  //       pid: 'root_mix',
  //       srAmount: 100,
  //       srId: 2,
  //       rrAmount: 100,
  //       rrId: 3,
  //       balance: 100,
  //       status: TransactionStatus.active.index,
  //       closable: false,
  //       timestamp: DateTime.now().microsecondsSinceEpoch,
  //       meta: {},
  //     );

  //     final leafClosed = leafActive.copyWith(
  //       tid: 'leaf_closed_mix',
  //       srAmount: 200,
  //       rrAmount: 200,
  //       status: TransactionStatus.closed.index,
  //       closable: true,
  //     );

  //     await repo.add(leafActive);
  //     await repo.add(leafClosed);

  //     final updatedRoot = box.get('root_mix')!;
  //     expect(updatedRoot.balance, 100); // 400 - (100+200)
  //     expect(updatedRoot.statusEnum, TransactionStatus.partial);

  //     final updatedLeafActive = box.get('leaf_active')!;
  //     expect(updatedLeafActive.statusEnum, TransactionStatus.active);

  //     final updatedLeafClosed = box.get('leaf_closed_mix')!;
  //     expect(updatedLeafClosed.statusEnum, TransactionStatus.closed);
  //   });
  // });
}
