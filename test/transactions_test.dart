import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/app/exceptions.dart';
import 'package:jxledger/features/transactions/adapter.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/repository.dart';
import 'package:jxledger/features/transactions/calculations.dart';

import 'faker/hive.dart';

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
        await repo.update(tx.copyWith(srAmount: Decimal.fromInt(-1)));
      } on ValidationException catch (e) {
        expect(e.code, 1005);
      }

      try {
        await repo.update(tx.copyWith(rrAmount: Decimal.fromInt(-1)));
      } on ValidationException catch (e) {
        expect(e.code, 1006);
      }

      try {
        await repo.update(tx.copyWith(balance: Decimal.fromInt(-1)));
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
        expect(e.code, tx.isCapital ? 1010 : 1102);
      }

      try {
        await repo.update(tx.copyWith(pid: '1', tid: '2', rid: '3'));
      } on ValidationException catch (e) {
        expect(e.code, tx.isCapital ? 1010 : 1101);
      }

      try {
        await repo.update(tx.copyWith(pid: '1', tid: 'root', rid: '3'));
      } on ValidationException catch (e) {
        expect(e.code, tx.isCapital ? 1010 : 1102);
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
      repo.box = HiveBoxFaker<TransactionsModel>('transactions_test', hiveBoxOverride: box);
      repo.boxNameDefault = 'transactions_test';
    });

    test('root -> Add, Update and Remove', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(100),
        srId: 1,
        rrAmount: Decimal.fromInt(100),
        rrId: 2,
        balance: Decimal.fromInt(100),
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
        balance: Decimal.fromInt(80), // Balance isn't guarded. Maybe we need to guard this?
        status: TransactionStatus.active.index,
      );
      await repo.update(rr);

      expect(rr.balance, Decimal.fromInt(80));

      // Test root against basic validation rules
      await testBasicTxValidation(rr);

      // Finally remove the root
      await repo.remove(root);
      expect(repo.isEmpty(), true);
    });

    test('preserves precise Decimal values through repository create/update/trade/close/finalize flows', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.parse('100.1234567890123456789'),
        srId: 1,
        rrAmount: Decimal.parse('100.1234567890123456789'),
        rrId: 2,
        balance: Decimal.parse('100.1234567890123456789'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(root);

      final createdRoot = box.get('root')!;
      expect(createdRoot.srAmount, Decimal.parse('100.1234567890123456789'));
      expect(createdRoot.rrAmount, Decimal.parse('100.1234567890123456789'));
      expect(createdRoot.balance, Decimal.parse('100.1234567890123456789'));

      final editedRoot = createdRoot.copyWith(
        srAmount: Decimal.parse('101.1234567890123456789'),
        rrAmount: Decimal.parse('101.1234567890123456789'),
        balance: Decimal.parse('101.1234567890123456789'),
      );
      await repo.update(editedRoot);

      final updatedRoot = box.get('root')!;
      expect(updatedRoot.srAmount, Decimal.parse('101.1234567890123456789'));
      expect(updatedRoot.rrAmount, Decimal.parse('101.1234567890123456789'));
      expect(updatedRoot.balance, Decimal.parse('101.1234567890123456789'));

      final tradeChild = TransactionsModel(
        tid: 'trade_child',
        rid: 'root',
        pid: 'root',
        srAmount: Decimal.parse('40.1234567890123456789'),
        srId: 2,
        rrAmount: Decimal.parse('40.1234567890123456789'),
        rrId: 3,
        balance: Decimal.parse('40.1234567890123456789'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(tradeChild);

      final parentAfterTrade = box.get('root')!;
      expect(parentAfterTrade.balance, Decimal.parse('61'));
      expect(parentAfterTrade.statusEnum, TransactionStatus.partial);

      final updatedTradeChild = box
          .get('trade_child')!
          .copyWith(
            srAmount: Decimal.parse('25.9876543210987654321'),
            rrAmount: Decimal.parse('25.9876543210987654321'),
            balance: Decimal.parse('25.9876543210987654321'),
          );
      await repo.update(updatedTradeChild);

      final storedTradeChild = box.get('trade_child')!;
      expect(storedTradeChild.srAmount, Decimal.parse('25.9876543210987654321'));
      expect(storedTradeChild.rrAmount, Decimal.parse('25.9876543210987654321'));
      expect(storedTradeChild.balance, Decimal.parse('25.9876543210987654321'));

      final parentAfterEdit = box.get('root')!;
      expect(parentAfterEdit.balance, Decimal.parse('75.1358024679135802468'));

      final parentNode = TransactionsModel(
        tid: 'parent_node',
        rid: 'root',
        pid: 'root',
        srAmount: Decimal.parse('10.9876543210987654321'),
        srId: 2,
        rrAmount: Decimal.parse('10.9876543210987654321'),
        rrId: 3,
        balance: Decimal.parse('10.9876543210987654321'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(parentNode);
      final rootAfterParent = box.get('root')!;
      expect(rootAfterParent.balance, Decimal.parse('64.1481481468148148147'));

      final closeableLeaf = TransactionsModel(
        tid: 'closeable_leaf',
        rid: 'root',
        pid: 'parent_node',
        srAmount: Decimal.parse('5.1234567890123456789'),
        srId: 3,
        rrAmount: Decimal.parse('5.1234567890123456789'),
        rrId: 2,
        balance: Decimal.parse('5.1234567890123456789'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(closeableLeaf);
      final parentAfterLeaf = box.get('parent_node')!;
      expect(parentAfterLeaf.balance, Decimal.parse('5.8641975320864197532'));

      final updatedLeaf = box
          .get('closeable_leaf')!
          .copyWith(
            srAmount: Decimal.parse('4.1111111111111111111'),
            rrAmount: Decimal.parse('4.1111111111111111111'),
            balance: Decimal.parse('4.1111111111111111111'),
          );
      await repo.update(updatedLeaf);

      final storedLeaf = box.get('closeable_leaf')!;
      expect(storedLeaf.srAmount, Decimal.parse('4.1111111111111111111'));
      expect(storedLeaf.rrAmount, Decimal.parse('4.1111111111111111111'));
      expect(storedLeaf.balance, Decimal.parse('4.1111111111111111111'));

      await repo.close(storedLeaf);

      final closedLeaf = box.get('closeable_leaf')!;
      expect(closedLeaf.statusEnum, TransactionStatus.closed);
      expect(closedLeaf.balance, Decimal.zero);

      final parentAfterClose = box.get('parent_node')!;
      expect(parentAfterClose.balance, Decimal.parse('6.876543209987654321'));

      await repo.finalize(parentAfterClose);

      final finalizedParent = box.get('parent_node')!;
      expect(finalizedParent.statusEnum, TransactionStatus.finalized);
      expect(finalizedParent.balance, Decimal.parse('6.876543209987654321'));
    });

    test('root -> Capital Mode, Add, Update and Remove', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(100),
        srId: 1,
        rrAmount: Decimal.fromInt(100),
        rrId: 1,
        balance: Decimal.fromInt(100),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {"isCapital": true},
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
        balance: Decimal.fromInt(80), // Balance isn't guarded. Maybe we need to guard this?
        status: TransactionStatus.active.index,
      );
      await repo.update(rr);

      expect(rr.balance, Decimal.fromInt(80));

      // Test root against basic validation rules
      await testBasicTxValidation(rr);

      // Finally remove the root
      await repo.remove(root);
      expect(repo.isEmpty(), true);
    });

    test('leaf -> Add, Update, Close, Refund, Remove and Finalize', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(200),
        srId: 1,
        rrAmount: Decimal.fromInt(200),
        rrId: 2,
        balance: Decimal.fromInt(200),
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
        srAmount: Decimal.fromInt(120),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
      expect(rr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 120
      expect(leaf_1.balance, Decimal.fromInt(120));

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
        srAmount: Decimal.fromInt(80),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
      expect(rrr.balance, Decimal.fromInt(0));

      // 2. root status should be inactive
      expect(rrr.statusEnum, TransactionStatus.inactive);

      // 3. leaf_1c balance should be 120
      expect(leaf_1c.balance, Decimal.fromInt(120));

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
      expect(rrrr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1c should be removed from the box
      expect(box.get('leaf_1c'), null);

      final leaf_2 = TransactionsModel(
        tid: 'leaf_2',
        rid: 'root',
        pid: 'leaf_1',
        srAmount: Decimal.fromInt(50),
        srId: 3,
        rrAmount: Decimal.fromInt(50),
        rrId: 2,
        balance: Decimal.fromInt(50),
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
      expect(rrrrr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 70
      expect(l1.balance, Decimal.fromInt(70));

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
      expect(rrrrrr.balance, Decimal.fromInt(130));

      // 2. root status should be partial as leaf_1 is still partial
      expect(rrrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_2 status should be closed
      expect(l2.statusEnum, TransactionStatus.closed);

      // 4. leaf_2 balance should be 0
      expect(l2.balance, Decimal.fromInt(0));

      // 5. leaf_1 status should be still partial
      expect(ll1.statusEnum, TransactionStatus.partial);

      // 6. leaf_1 balance should be still 70
      expect(ll1.balance, Decimal.fromInt(70));

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

      // CHECKPOINT:
      final rootTx = box.get('root')!;
      final leaf1Tx = box.get('leaf_1')!;

      // 1. Root should not be finalizable while leaf_1 is still partial
      try {
        repo.canFinalize(rootTx, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, AppErrorCode.txUpdateFinalizableRequiresInactiveLeaves);
      }

      // 2. Leaf_1 should not be finalizable while it has children
      try {
        repo.canFinalize(leaf1Tx, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, AppErrorCode.txUpdateFinalizableRequiresInactiveLeaves);
      }

      // 3. Finalize leaf_2 manually to make it inactive
      try {
        await repo.finalize(leaf1Tx);
      } on ValidationException catch (e) {
        fail('Finalizing leaf failed: $e');
      }

      // 4. Now root has only inactive/closed leaves → should be finalizable
      try {
        repo.canFinalize(rootTx, silent: true);
      } on ValidationException catch (_) {
        fail('Root should be finalizable now');
      }

      try {
        repo.finalize(rootTx);
      } on ValidationException catch (e) {
        fail('Finalizing root failed: $e');
      }
    });

    test('leaf with root capital mode -> Add, Update, Close, Refund and Remove', () async {
      await box.clear();

      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(200),
        srId: 2,
        rrAmount: Decimal.fromInt(200),
        rrId: 2,
        balance: Decimal.fromInt(200),
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
        srAmount: Decimal.fromInt(120),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
      expect(rr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 120
      expect(leaf_1.balance, Decimal.fromInt(120));

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
        srAmount: Decimal.fromInt(80),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
      expect(rrr.balance, Decimal.fromInt(0));

      // 2. root status should be inactive
      expect(rrr.statusEnum, TransactionStatus.inactive);

      // 3. leaf_1c balance should be 120
      expect(leaf_1c.balance, Decimal.fromInt(120));

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
      expect(rrrr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1c should be removed from the box
      expect(box.get('leaf_1c'), null);

      final leaf_2 = TransactionsModel(
        tid: 'leaf_2',
        rid: 'root',
        pid: 'leaf_1',
        srAmount: Decimal.fromInt(50),
        srId: 3,
        rrAmount: Decimal.fromInt(50),
        rrId: 2,
        balance: Decimal.fromInt(50),
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
      expect(rrrrr.balance, Decimal.fromInt(80));

      // 2. root status should be partial
      expect(rrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_1 balance should be 70
      expect(l1.balance, Decimal.fromInt(70));

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
      expect(rrrrrr.balance, Decimal.fromInt(130));

      // 2. root status should be partial as leaf_1 is still partial
      expect(rrrrrr.statusEnum, TransactionStatus.partial);

      // 3. leaf_2 status should be closed
      expect(l2.statusEnum, TransactionStatus.closed);

      // 4. leaf_2 balance should be 0
      expect(l2.balance, Decimal.fromInt(0));

      // 5. leaf_1 status should be still partial
      expect(ll1.statusEnum, TransactionStatus.partial);

      // 6. leaf_1 balance should be still 70
      expect(ll1.balance, Decimal.fromInt(70));

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

      // CHECKPOINT:
      final rootTx = box.get('root')!;
      final leaf1Tx = box.get('leaf_1')!;

      // 1. Root should not be finalizable while leaf_1 is still partial
      try {
        repo.canFinalize(rootTx, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, AppErrorCode.txUpdateFinalizableRequiresInactiveLeaves);
      }

      // 2. Leaf_1 should not be finalizable while it has children
      try {
        repo.canFinalize(leaf1Tx, silent: true);
      } on ValidationException catch (e) {
        expect(e.code, AppErrorCode.txUpdateFinalizableRequiresInactiveLeaves);
      }

      // 3. Finalize leaf_2 manually to make it inactive
      try {
        await repo.finalize(leaf1Tx);
      } on ValidationException catch (e) {
        fail('Finalizing leaf failed: $e');
      }

      // 4. Now root has only inactive/closed leaves → should be finalizable
      try {
        repo.canFinalize(rootTx, silent: true);
      } on ValidationException catch (_) {
        fail('Root should be finalizable now');
      }

      try {
        repo.finalize(rootTx);
      } on ValidationException catch (e) {
        fail('Finalizing root failed: $e');
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
      repo.box = HiveBoxFaker<TransactionsModel>('transactions_test', hiveBoxOverride: box);
      repo.boxNameDefault = 'transactions_test';
    });

    test('root -> leaf balance decreases correctly', () async {
      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(100),
        srId: 1,
        rrAmount: Decimal.fromInt(100),
        rrId: 2,
        balance: Decimal.fromInt(100),
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
        srAmount: Decimal.fromInt(40),
        srId: 2,
        rrAmount: Decimal.fromInt(40),
        rrId: 3,
        balance: Decimal.fromInt(40),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf);

      final updatedRoot = box.get('root')!;
      expect(updatedRoot.balance, Decimal.fromInt(60));
      expect(updatedRoot.statusEnum, TransactionStatus.partial);
    });

    test('root -> leaf -> leaf balance propagates correctly', () async {
      final root = TransactionsModel(
        tid: 'root2',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(200),
        srId: 1,
        rrAmount: Decimal.fromInt(200),
        rrId: 2,
        balance: Decimal.fromInt(200),
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
        srAmount: Decimal.fromInt(120),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
        srAmount: Decimal.fromInt(50),
        srId: 3,
        rrAmount: Decimal.fromInt(50),
        rrId: 2, // This is the same as root to test closable logic
        balance: Decimal.fromInt(50),
        status: TransactionStatus.active.index,
        closable: false, // This is intentionally false to test if it gets updated to true
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf2);

      final updatedRoot = box.get('root2')!;
      expect(updatedRoot.balance, Decimal.fromInt(80)); // 200 - 120

      // The root is still partial because leaf21 doesnt use all of its balance
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      final updatedLeaf21 = box.get('leaf21')!;
      expect(updatedLeaf21.balance, Decimal.fromInt(70)); // 120 - 50

      // The leaf21 is still partial because leaf22 doesnt use all of its balance
      expect(updatedLeaf21.statusEnum, TransactionStatus.partial);

      final updatedLeaf22 = box.get('leaf22')!;
      expect(updatedLeaf22.balance, Decimal.fromInt(50)); // 50

      // Leaf22 is active because it has no children
      expect(updatedLeaf22.statusEnum, TransactionStatus.active);

      // Leaf22 should be closable because its balance coin type is the same as the root [need to make test that drill further than 2 parent]
      expect(updatedLeaf22.closable, true);
    });
  });

  group('Transactions with root as capital balance propagation', () {
    late TransactionsRepository repo;
    late Box<TransactionsModel> box;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_test');
      await box.clear();
      repo = TransactionsRepository();
      repo.box = HiveBoxFaker<TransactionsModel>('transactions_test', hiveBoxOverride: box);
      repo.boxNameDefault = 'transactions_test';
    });

    test('root -> leaf balance decreases correctly', () async {
      final root = TransactionsModel(
        tid: 'root',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(100),
        srId: 2,
        rrAmount: Decimal.fromInt(100),
        rrId: 2,
        balance: Decimal.fromInt(100),
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
        srAmount: Decimal.fromInt(40),
        srId: 2,
        rrAmount: Decimal.fromInt(40),
        rrId: 3,
        balance: Decimal.fromInt(40),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf);

      final updatedRoot = box.get('root')!;
      expect(updatedRoot.balance, Decimal.fromInt(60));
      expect(updatedRoot.statusEnum, TransactionStatus.partial);
    });

    test('root -> leaf -> leaf balance propagates correctly', () async {
      final root = TransactionsModel(
        tid: 'root2',
        rid: '0',
        pid: '0',
        srAmount: Decimal.fromInt(200),
        srId: 1,
        rrAmount: Decimal.fromInt(200),
        rrId: 2,
        balance: Decimal.fromInt(200),
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
        srAmount: Decimal.fromInt(120),
        srId: 2,
        rrAmount: Decimal.fromInt(120),
        rrId: 3,
        balance: Decimal.fromInt(120),
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
        srAmount: Decimal.fromInt(50),
        srId: 3,
        rrAmount: Decimal.fromInt(50),
        rrId: 2, // This is the same as root to test closable logic
        balance: Decimal.fromInt(50),
        status: TransactionStatus.active.index,
        closable: false, // This is intentionally false to test if it gets updated to true
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf2);

      final updatedRoot = box.get('root2')!;
      expect(updatedRoot.balance, Decimal.fromInt(80)); // 200 - 120

      // The root is still partial because leaf21 doesnt use all of its balance
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      final updatedLeaf21 = box.get('leaf21')!;
      expect(updatedLeaf21.balance, Decimal.fromInt(70)); // 120 - 50

      // The leaf21 is still partial because leaf22 doesnt use all of its balance
      expect(updatedLeaf21.statusEnum, TransactionStatus.partial);

      final updatedLeaf22 = box.get('leaf22')!;
      expect(updatedLeaf22.balance, Decimal.fromInt(50)); // 50

      // Leaf22 is active because it has no children
      expect(updatedLeaf22.statusEnum, TransactionStatus.active);

      // Leaf22 should be closable because its balance coin type is the same as the root [need to make test that drill further than 2 parent]
      expect(updatedLeaf22.closable, true);
    });
  });

  group('Edge cases', () {
    late TransactionsRepository repo;
    late Box<TransactionsModel> box;

    setUp(() async {
      box = await Hive.openBox<TransactionsModel>('transactions_test');
      await box.clear();
      repo = TransactionsRepository();
      repo.box = HiveBoxFaker<TransactionsModel>('transactions_test', hiveBoxOverride: box);
      repo.boxNameDefault = 'transactions_test';
    });
    test('root -> leaf with ugly fractional balance rounding', () async {
      final root = TransactionsModel(
        tid: 'rootFrac',
        rid: '0',
        pid: '0',
        srAmount: Decimal.parse('2.87777'),
        srId: 1,
        rrAmount: Decimal.parse('2.87777'),
        rrId: 2,
        balance: Decimal.parse('2.87777'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(root);

      // Simulate a trade that consumes almost all of root’s balance
      final leaf = TransactionsModel(
        tid: 'leafFrac',
        rid: 'rootFrac',
        pid: 'rootFrac',
        srAmount: Decimal.parse('2.8777699999999999999999999999'),
        srId: 2,
        rrAmount: Decimal.parse('2.8777699999999999999999999999'),
        rrId: 3,
        balance: Decimal.parse('2.8777699999999999999999999999'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf);

      final updatedRoot = box.get('rootFrac')!;
      final updatedLeaf = box.get('leafFrac')!;

      // Expect root balance to be a microscopic remainder
      // This is the "bad rounding crap" case
      expect(updatedRoot.balance <= Decimal.parse('0.0000000000000000000000014'), true);

      // Root should be marked partial, not finalized, because it still has nonzero balance
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      // Leaf is active since it has no children
      expect(updatedLeaf.statusEnum, TransactionStatus.active);
    });

    test('root -> leaf leaves exact 18-decimal remainder', () async {
      final root = TransactionsModel(
        tid: 'rootPrecise',
        rid: '0',
        pid: '0',
        srAmount: Decimal.parse('1.000000000000000001'),
        srId: 1,
        rrAmount: Decimal.parse('1.000000000000000001'),
        rrId: 2,
        balance: Decimal.parse('1.000000000000000001'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(root);

      final leaf = TransactionsModel(
        tid: 'leafPrecise',
        rid: 'rootPrecise',
        pid: 'rootPrecise',
        srAmount: Decimal.parse('1.000000000000000000'),
        srId: 2,
        rrAmount: Decimal.parse('1.000000000000000000'),
        rrId: 3,
        balance: Decimal.parse('1.000000000000000000'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );

      await repo.add(leaf);

      final updatedRoot = box.get('rootPrecise')!;
      final updatedLeaf = box.get('leafPrecise')!;

      // Root should have exactly 0.000000000000000001 left
      expect(updatedRoot.balance, Decimal.parse('0.000000000000000001'));

      // Root is partial because it still has nonzero balance
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      // Leaf is active since it has no children
      expect(updatedLeaf.statusEnum, TransactionStatus.active);
    });

    test('txA -> txB -> txC close propagation with 18-decimal precision', () async {
      final txA = TransactionsModel(
        tid: 'txA',
        rid: '0',
        pid: '0',
        srAmount: Decimal.parse('10.000000000000000000'),
        srId: 1,
        rrAmount: Decimal.parse('10.000000000000000000'),
        rrId: 3,
        balance: Decimal.parse('10.000000000000000000'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );
      await repo.add(txA);

      final txB = TransactionsModel(
        tid: 'txB',
        rid: 'txA',
        pid: 'txA',
        srAmount: Decimal.parse('6.000000000000000000'),
        srId: 3,
        rrAmount: Decimal.parse('6.000000000000000000'),
        rrId: 7,
        balance: Decimal.parse('6.000000000000000000'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );
      await repo.add(txB);

      final txC = TransactionsModel(
        tid: 'txC',
        rid: 'txB',
        pid: 'txB',
        srAmount: Decimal.parse('6.000000000000000000'),
        srId: 7,
        rrAmount: Decimal.parse('6.000000000000000000'),
        rrId: 3, // matches txA rrId, so closable
        balance: Decimal.parse('6.000000000000000000'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );
      await repo.add(txC);

      // Check balances before close
      final updatedA = box.get('txA')!;
      final updatedB = box.get('txB')!;
      final updatedC = box.get('txC')!;

      expect(updatedA.balance, Decimal.parse('4.000000000000000000')); // 10 - 6
      expect(updatedA.statusEnum, TransactionStatus.partial);

      expect(updatedB.balance, Decimal.zero); // fully consumed by txC
      expect(updatedB.statusEnum, TransactionStatus.inactive);

      expect(updatedC.balance, Decimal.parse('6.000000000000000000'));
      expect(updatedC.statusEnum, TransactionStatus.active);
      expect(updatedC.closable, true);

      // Now close txC
      await repo.close(updatedC);

      final closedA = box.get('txA')!;
      final closedB = box.get('txB')!;
      final closedC = box.get('txC')!;

      // txC’s balance should propagate back up to txA
      expect(closedA.balance, Decimal.parse('10.000000000000000000'));
      expect(closedA.statusEnum, TransactionStatus.active);

      // txB remains partial (it was just a conduit)
      expect(closedB.statusEnum, TransactionStatus.inactive);

      // txC is closed
      expect(closedC.statusEnum, TransactionStatus.closed);
    });

    test('double vs decimal subtraction and transaction propagation', () async {
      // --- Double fails ---
      double d1 = 0.3489440039038948;
      double d2 = 0.3489440039038947;
      double diffDouble = d1 - d2;

      // Double cannot represent these exactly, so the subtraction is ugly
      expect(diffDouble.toString(), isNot('0.0000000000000001'));

      // --- Decimal succeeds ---
      final dec1 = Decimal.parse('0.3489440039038948');
      final dec2 = Decimal.parse('0.3489440039038947');
      final diffDecimal = dec1 - dec2;

      // Decimal preserves exact digits
      expect(diffDecimal, Decimal.parse('0.0000000000000001'));

      // --- Transactions with Decimal should not fail like double ---
      final root = TransactionsModel(
        tid: 'rootFrac',
        rid: '0',
        pid: '0',
        srAmount: Decimal.parse('0.3489440039038948'),
        srId: 1,
        rrAmount: Decimal.parse('0.3489440039038948'),
        rrId: 2,
        balance: Decimal.parse('0.3489440039038948'),
        status: TransactionStatus.active.index,
        closable: true,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );
      await repo.add(root);

      final leaf = TransactionsModel(
        tid: 'leafFrac',
        rid: 'rootFrac',
        pid: 'rootFrac',
        srAmount: Decimal.parse('0.3489440039038947'),
        srId: 2,
        rrAmount: Decimal.parse('0.3489440039038947'),
        rrId: 3,
        balance: Decimal.parse('0.3489440039038947'),
        status: TransactionStatus.active.index,
        closable: false,
        timestamp: DateTime.now().microsecondsSinceEpoch,
        meta: {},
      );
      await repo.add(leaf);

      final updatedRoot = box.get('rootFrac')!;
      final updatedLeaf = box.get('leafFrac')!;

      // Root should have exactly 0.0000000000000001 left
      expect(updatedRoot.balance, Decimal.parse('0.0000000000000001'));
      expect(updatedRoot.statusEnum, TransactionStatus.partial);

      // Leaf is active
      expect(updatedLeaf.statusEnum, TransactionStatus.active);
    });
  });

  test('traceCapitalUsed() -> multi-hop lineage calculation', () {
    final txA = TransactionsModel(
      tid: 'A',
      pid: '0',
      rid: '0',
      srAmount: Decimal.parse('100'),
      srId: 1,
      rrAmount: Decimal.parse('100'),
      rrId: 2,
      balance: Decimal.parse('50'), // 50 used by B
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: 1,
      meta: {},
    );

    final txB = TransactionsModel(
      tid: 'B',
      pid: 'A',
      rid: 'A',
      srAmount: Decimal.parse('50'),
      srId: 2,
      rrAmount: Decimal.parse('25'),
      rrId: 3,
      balance: Decimal.parse('3'), // 22 used by C
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 2,
      meta: {},
    );

    final txC = TransactionsModel(
      tid: 'C',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('22'),
      srId: 3,
      rrAmount: Decimal.parse('300'),
      rrId: 4,
      balance: Decimal.parse('289'), // 11 used by D
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txD = TransactionsModel(
      tid: 'D',
      pid: 'C',
      rid: 'A',
      srAmount: Decimal.parse('11'),
      srId: 4,
      rrAmount: Decimal.parse('400'),
      rrId: 5,
      balance: Decimal.parse('400'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 4,
      meta: {},
    );

    final txs = [txA, txB, txC, txD];
    final calc = TransactionCalculation();
    final result = calc.totalCapitalUsed(txD, txs);

    expect(result.toString().startsWith('1.6133333333'), true);
  });

  test('CRAZY PROOF: 6-Level Lineage with strict parent.rrId == child.srId enforcement', () {
    final calc = TransactionCalculation();

    final txA = TransactionsModel(
      tid: 'A',
      pid: '0',
      rid: '0',
      srAmount: Decimal.parse('10000'),
      srId: 1,
      rrAmount: Decimal.parse('10000'),
      rrId: 2,
      balance: Decimal.parse('5000'),
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: 1,
      meta: {},
    );

    final txB = TransactionsModel(
      tid: 'B',
      pid: 'A',
      rid: 'A',
      srAmount: Decimal.parse('5000'),
      srId: 2,
      rrAmount: Decimal.parse('5000'),
      rrId: 3,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 2,
      meta: {},
    );

    final txcValid = TransactionsModel(
      tid: 'C_Valid',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('400'),
      srId: 3,
      rrAmount: Decimal.parse('4000'),
      rrId: 4,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txD = TransactionsModel(
      tid: 'D',
      pid: 'C_Valid',
      rid: 'A',
      srAmount: Decimal.parse('2500'),
      srId: 4,
      rrAmount: Decimal.parse('2500'),
      rrId: 5,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 4,
      meta: {},
    );

    final txE = TransactionsModel(
      tid: 'E',
      pid: 'D',
      rid: 'A',
      srAmount: Decimal.parse('2000'),
      srId: 5,
      rrAmount: Decimal.parse('2000'),
      rrId: 6,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 5,
      meta: {},
    );

    final txfValidleaf = TransactionsModel(
      tid: 'F_Valid',
      pid: 'E',
      rid: 'A',
      srAmount: Decimal.parse('1200'),
      srId: 6,
      rrAmount: Decimal.parse('1200'),
      rrId: 7,
      balance: Decimal.parse('0'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 6,
      meta: {},
    );

    final validTxs = [txA, txB, txcValid, txD, txE, txfValidleaf];
    final resultValid = calc.totalCapitalUsed(txfValidleaf, validTxs);
    expect(resultValid.toString(), Decimal.parse('120').toString());

    // SCENARIO 2: Broken Lineage Pool Mismatch
    final txcImposter = TransactionsModel(
      tid: 'C_Imposter',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('400'),
      srId: 3,
      rrAmount: Decimal.parse('4000'),
      rrId: 99, // Imposter Pool
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txdBroken = TransactionsModel(
      tid: 'D_Broken',
      pid: 'C_Imposter',
      rid: 'A',
      srAmount: Decimal.parse('2500'),
      srId: 4,
      rrAmount: Decimal.parse('2500'),
      rrId: 5,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 4,
      meta: {},
    );

    final txeBrokenpath = TransactionsModel(
      tid: 'E_Broken',
      pid: 'D_Broken',
      rid: 'A',
      srAmount: Decimal.parse('2000'),
      srId: 5,
      rrAmount: Decimal.parse('2000'),
      rrId: 6,
      balance: Decimal.parse('0'),
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 5,
      meta: {},
    );

    final txfBrokenleaf = TransactionsModel(
      tid: 'F_Broken',
      pid: 'E_Broken',
      rid: 'A',
      srAmount: Decimal.parse('1200'),
      srId: 6,
      rrAmount: Decimal.parse('1200'),
      rrId: 7,
      balance: Decimal.parse('0'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 6,
      meta: {},
    );

    final brokenTxs = [txA, txB, txcImposter, txdBroken, txeBrokenpath, txfBrokenleaf];
    final resultBroken = calc.totalCapitalUsed(txfBrokenleaf, brokenTxs);
    expect(resultBroken.toString(), Decimal.parse('0').toString());
  });

  test('PROFIT TEST 1: Child takes EXACTLY the profit amount -> 0 capital used', () {
    final calc = TransactionCalculation();

    final txA_Root = TransactionsModel(
      tid: 'A',
      pid: '0',
      rid: '0',
      srAmount: Decimal.parse('120'),
      srId: 1,
      rrAmount: Decimal.parse('120'),
      rrId: 2,
      balance: Decimal.parse('120'),
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: 1,
      meta: {},
    );

    final txB_Profitable = TransactionsModel(
      tid: 'B',
      pid: 'A',
      rid: 'A',
      srAmount: Decimal.parse('120'),
      srId: 2,
      rrAmount: Decimal.parse('120'),
      rrId: 3,
      balance: Decimal.parse('140'), // 20 units of pure profit surplus
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 2,
      meta: {},
    );

    final txC_SkimmingLeaf = TransactionsModel(
      tid: 'C',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('20'),
      srId: 3, // Claims exactly the 20 profit units
      rrAmount: Decimal.parse('20'),
      rrId: 4,
      balance: Decimal.parse('0'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txs = [txA_Root, txB_Profitable, txC_SkimmingLeaf];
    final result = calc.totalCapitalUsed(txC_SkimmingLeaf, txs);

    // Expected: 0 original capital spent
    expect(result.toString(), Decimal.parse('0').toString());
  });

  test('PROFIT TEST 2: Child takes LESS than the profit amount -> 0 capital used', () {
    final calc = TransactionCalculation();

    final txA_Root = TransactionsModel(
      tid: 'A',
      pid: '0',
      rid: '0',
      srAmount: Decimal.parse('120'),
      srId: 1,
      rrAmount: Decimal.parse('120'),
      rrId: 2,
      balance: Decimal.parse('120'),
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: 1,
      meta: {},
    );

    final txB_Profitable = TransactionsModel(
      tid: 'B',
      pid: 'A',
      rid: 'A',
      srAmount: Decimal.parse('120'),
      srId: 2,
      rrAmount: Decimal.parse('120'),
      rrId: 3,
      balance: Decimal.parse('140'), // 20 units of pure profit surplus
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 2,
      meta: {},
    );

    final txC_SmallSkimmingLeaf = TransactionsModel(
      tid: 'C',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('5'),
      srId: 3, // Claims 5 units (safely below the 20 profit pool)
      rrAmount: Decimal.parse('5'),
      rrId: 4,
      balance: Decimal.parse('0'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txs = [txA_Root, txB_Profitable, txC_SmallSkimmingLeaf];
    final result = calc.totalCapitalUsed(txC_SmallSkimmingLeaf, txs);

    // Expected: 0 original capital spent (entirely absorbed by yield cushion)
    expect(result.toString(), Decimal.parse('0').toString());
  });

  test('PROFIT TEST 3: Child takes MORE than the profit amount -> Only traces the spillover principal', () {
    final calc = TransactionCalculation();

    final txA_Root = TransactionsModel(
      tid: 'A',
      pid: '0',
      rid: '0',
      srAmount: Decimal.parse('120'),
      srId: 1,
      rrAmount: Decimal.parse('120'),
      rrId: 2,
      balance: Decimal.parse('120'),
      status: TransactionStatus.active.index,
      closable: true,
      timestamp: 1,
      meta: {},
    );

    final txB_Profitable = TransactionsModel(
      tid: 'B',
      pid: 'A',
      rid: 'A',
      srAmount: Decimal.parse('120'),
      srId: 2,
      rrAmount: Decimal.parse('120'),
      rrId: 3,
      balance: Decimal.parse('140'), // 20 units of pure profit surplus
      status: TransactionStatus.active.index,
      closable: false,
      timestamp: 2,
      meta: {},
    );

    final txC_HeavyLeaf = TransactionsModel(
      tid: 'C',
      pid: 'B',
      rid: 'A',
      srAmount: Decimal.parse('50'),
      srId: 3, // Claims 50 units (Exceeds profit cushion by 30 units)
      rrAmount: Decimal.parse('50'),
      rrId: 4,
      balance: Decimal.parse('0'),
      status: TransactionStatus.finalized.index,
      closable: false,
      timestamp: 3,
      meta: {},
    );

    final txs = [txA_Root, txB_Profitable, txC_HeavyLeaf];
    final result = calc.totalCapitalUsed(txC_HeavyLeaf, txs);

    // =========================================================================
    // MATHEMATICAL LOGIC BREAKDOWN
    // =========================================================================
    // 1. Profit Surplus = 140 (balance) - 120 (rrAmount) = 20
    // 2. Child wants 50. Subtracting profit = 50 - 20 = 30 core units tracked.
    // 3. Hop C -> B Pct = 30 / 120 (parent principal) = 0.25
    // 4. Root Calculation = 120 (Root Principal) * 0.25 = 30
    // =========================================================================
    expect(result.toString(), Decimal.parse('30').toString());
  });
}
