import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/app/exceptions.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/repository.dart';

void main() async {
  // Initialize Hive in memory for testing
  Hive.init('./test/database');
  Hive.registerAdapter(TransactionsAdapter());

  group('Transactions Operations', () {
    late TransactionsRepository repo;
    late Box<TransactionsModel> box;

    testBasicTxValidation(TransactionsModel tx) async {
      try {
        await repo.update(tx.copyWith(tid: '0'));
      } on ValidationException catch (e) {
        expect(e.code, 1001);
      }

      try {
        await repo.update(tx.copyWith(rid: '0'));
      } on ValidationException catch (e) {
        expect(e.code, tx.isRoot ? 1002 : 1004);
      }

      try {
        await repo.update(tx.copyWith(pid: '0'));
      } on ValidationException catch (e) {
        expect(e.code, tx.isRoot ? 1003 : 1004);
      }

      try {
        await repo.update(tx.copyWith(srAmount: -1));
      } on ValidationException catch (e) {
        expect(e.code, 1005);
      }

      try {
        await repo.update(tx.copyWith(rrAmount: -1));
      } on ValidationException catch (e) {
        expect(e.code, 1006);
      }

      try {
        await repo.update(tx.copyWith(balance: -1));
      } on ValidationException catch (e) {
        expect(e.code, 1007);
      }

      try {
        await repo.update(tx.copyWith(srId: -1));
      } on ValidationException catch (e) {
        expect(e.code, 1008);
      }

      try {
        await repo.update(tx.copyWith(rrId: -1));
      } on ValidationException catch (e) {
        expect(e.code, 1009);
      }

      try {
        await repo.update(tx.copyWith(rrId: 1, srId: 1));
      } on ValidationException catch (e) {
        expect(e.code, 1010);
      }

      try {
        await repo.update(tx.copyWith(status: -10));
      } on ValidationException catch (e) {
        expect(e.code, 1011);
      }

      try {
        await repo.update(tx.copyWith(timestamp: -10));
      } on ValidationException catch (e) {
        expect(e.code, 1012);
      }

      try {
        await repo.update(tx.copyWith(timestamp: DateTime.now().add(Duration(days: 1)).microsecondsSinceEpoch));
      } on ValidationException catch (e) {
        expect(e.code, 1013);
      }

      try {
        await repo.update(tx.copyWith(meta: {'invalid': Object()}));
      } on ValidationException catch (e) {
        expect(e.code, 1014);
      } catch (e) {
        // Error is expected because Hive will refused to insert incorrect map as defined in adapter
      }

      try {
        await repo.update(tx.copyWith(pid: '1', tid: 'root', rid: '3'));
      } on ValidationException catch (e) {
        expect(e.code, 1102);
      }

      try {
        await repo.update(tx.copyWith(pid: '1', tid: '2', rid: '3'));
      } on ValidationException catch (e) {
        expect(e.code, 1101);
      }

      try {
        await repo.update(tx.copyWith(pid: '1', tid: 'root', rid: '3'));
      } on ValidationException catch (e) {
        expect(e.code, 1102);
      }

      try {
        await repo.update(tx.copyWith(status: TransactionStatus.inactive.index));
      } on ValidationException catch (e) {
        expect(e.code, 1106);
      }

      try {
        await repo.update(tx.copyWith(status: TransactionStatus.partial.index));
      } on ValidationException catch (e) {
        expect(e.code, 1110);
      }
    }

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_test');
      await box.clear();
      repo = TransactionsRepository();
      repo.boxNameDefault = 'transactions_test';
    });

    test('root -> Add, Update and Remove', () async {
      await box.clear();

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

      // After adding root, it should be in the box
      expect(repo.isEmpty(), false);

      // Should be only 1 transaction in the box
      expect(repo.extract().length, 1);

      // Final check the root data, this is shallow test
      final r = box.get('root')!;
      expect(r.tid, 'root');
      expect(r.rid, '0');
      expect(r.pid, '0');

      final rr = r.copyWith(
        balance: 80, // Balance isn't guarded. Maybe we need to guard this?
        status: TransactionStatus.active.index,
      );
      await repo.update(rr);

      expect(rr.balance, 80);

      // Test root against basic validation rules
      await testBasicTxValidation(rr);

      // Finally remove the root
      await repo.remove(root);
      expect(repo.isEmpty(), true);
    });

    test('leaf -> Add, Update, Close, Refund and Remove', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
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

      final leaf_1 = TransactionsModel(
        tid: 'leaf_1',
        rid: 'root',
        pid: 'root',
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

      await repo.add(leaf_1);

      // After adding leaf, it should be in the box
      expect(repo.isEmpty(), false);

      // Should be only 1 transaction in the box
      expect(repo.extract().length, 2);

      // Test leaf against basic validation rules
      await testBasicTxValidation(leaf_1);

      // Refresh root, This is common Pitfall!, the add() will update the root!
      final rr = box.get('root')!;

      // CHECKPOINT:
      // 1. root balance should be 80
      expect(rr.balance, 80);

      // 2. root status should be partial
      expect(rr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 120
      expect(leaf_1.balance, 120);

      // 4. leaf_1 status should be active
      expect(leaf_1.statusEnum, TransactionStatus.active);

      // 5. leaf_1 should not be closable because its coin type is different from root
      expect(leaf_1.closable, false);
      try {
        repo.canClose(leaf_1, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, 1203);
      }

      // 6. leaf_1 should be refundable because it has no children
      try {
        repo.canRefund(leaf_1, silent: true);
      } on ValidationException catch (_) {
        // No error should be thrown
        fail('leaf_1 should be refundable');
      }

      final leaf_1c = TransactionsModel(
        tid: 'leaf_1c',
        rid: 'root',
        pid: 'root',
        srAmount: 80,
        srId: 2,
        rrAmount: 120,
        rrId: 3,
        balance: 120,
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf_1c);

      // Refresh root, This is common Pitfall!, the add() will update the root!
      final rrr = box.get('root')!;

      // CHECKPOINT:
      // 1. root balance should be 0
      expect(rrr.balance, 0);

      // 2. root status should be inactive
      expect(rrr.statusEnum, TransactionStatus.inactive);

      // 3. leaf_1c balance should be 120
      expect(leaf_1c.balance, 120);

      // 4. leaf_1c status should be active
      expect(leaf_1c.statusEnum, TransactionStatus.active);

      // 5. leaf_1c should not be closable because its coin type is different from root
      expect(leaf_1c.closable, false);
      try {
        repo.canClose(leaf_1c, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, 1203);
      }

      // 6. leaf_1c should be refundable because it has no children
      try {
        repo.canRefund(leaf_1c, silent: true);
      } on ValidationException catch (_) {
        // No error should be thrown
        fail('leaf_1 should be refundable');
      }

      // Now do the refund for leaf_1c
      // @TODO: This only testing refunding against 1 leaf level!, should expand this into multiple level of leaf.
      await repo.refund(leaf_1c);

      // Refresh root, This is common Pitfall!, the refund() will update the root!
      final rrrr = box.get('root')!;

      // CHECKPOINT:
      // 1. root balance should be 80
      expect(rrrr.balance, 80);

      // 2. root status should be partial
      expect(rrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1c should be removed from the box
      expect(box.get('leaf_1c'), null);

      final leaf_2 = TransactionsModel(
        tid: 'leaf_2',
        rid: 'root',
        pid: 'leaf_1',
        srAmount: 50,
        srId: 3,
        rrAmount: 50,
        rrId: 2,
        balance: 50,
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf_2);

      // After adding leaf, it should be in the box
      expect(repo.isEmpty(), false);

      // Should be only 1 transaction in the box
      expect(repo.extract().length, 3);

      // Test leaf against basic validation rules
      await testBasicTxValidation(leaf_2);

      // Refresh root, This is paranoid. as root probably doesnt change at this point!
      final rrrrr = box.get('root')!;

      // Refresh leaf1, This is common Pitfall!, the add() will update the leaf_1!
      final l1 = box.get('leaf_1')!;

      // CHECKPOINT:
      // 1. root balance should be 80
      expect(rrrrr.balance, 80);

      // 2. root status should be partial
      expect(rrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 70
      expect(l1.balance, 70);

      // 4. leaf_1 status should be partial
      expect(l1.statusEnum, TransactionStatus.partial);

      // 5. leaf_1 should not be closable because its coin type is different from root and it is not active state
      expect(l1.closable, false);
      try {
        repo.canClose(l1, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, 1202);
      }

      // 6. leaf_1 should not be refundable because it has children and it is inactive state
      try {
        repo.canRefund(l1, silent: true);
      } on ValidationException catch (e) {
        // No error should be thrown
        expect(e.code, 1601);
      }

      // Test close here
      await repo.close(leaf_2);

      // Refresh root, close() will mutate the closeTarget which is root in this case.
      final rrrrrr = box.get('root')!;

      // Refresh leaf_1
      final ll1 = box.get('leaf_1')!;

      // Refresh leaf_2
      final l2 = box.get('leaf_2')!;

      // CHECKPOINT:
      // 1. root balance should be 130
      expect(rrrrrr.balance, 130);

      // 2. root status should be partial as leaf_1 is still partial
      expect(rrrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_2 status should be closed
      expect(l2.statusEnum, TransactionStatus.closed);

      // 4. leaf_2 balance should be 0
      expect(l2.balance, 0);

      // 5. leaf_1 status should be still partial
      expect(ll1.statusEnum, TransactionStatus.partial);

      // 6. leaf_1 balance should be still 70
      expect(ll1.balance, 70);

      // 7. leaf_1 should not be closable because its coin type is different from root
      expect(ll1.closable, false);
      try {
        repo.canClose(ll1, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, 1202);
      }

      // 8. leaf_1 should not be refundable as it has inactive children, tx doesnt support partial refund yet!
      try {
        repo.canRefund(ll1, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, 1601);
      }
    });
  });

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
}
