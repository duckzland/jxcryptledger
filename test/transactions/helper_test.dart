import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/features/transactions/helper.dart';
import 'package:jxledger/features/transactions/model.dart';

Decimal _d(String value) => Decimal.parse(value);

TransactionsModel _tx({
  required String tid,
  String rid = '0',
  String pid = '0',
  String srAmount = '100',
  int srId = 1,
  String rrAmount = '100',
  int rrId = 2,
  String balance = '100',
  TransactionStatus status = TransactionStatus.active,
  bool closable = true,
  Map<String, dynamic> meta = const {},
}) {
  return TransactionsModel(
    tid: tid,
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
    meta: meta,
  );
}

void main() {
  // Tree 1 Structure (rid = 'r1'):
  //
  //          r1 (rrId: 10, root: pid == '0', rid == '0')
  //         /  \
  //        c1   c2 (rrId: 10)
  //       / \     \
  //     gc1 gc2   gc3 (rrId: 20)
  //   (rrId:10) (rrId:30)
  //
  // Tree 2 Structure (rid = 'r2'):
  //          r2 (rrId: 99, root)
  //          |
  //          d1 (rrId: 99)

  late TransactionsModel r1;
  late TransactionsModel c1;
  late TransactionsModel c2;
  late TransactionsModel gc1;
  late TransactionsModel gc2;
  late TransactionsModel gc3;

  late TransactionsModel r2;
  late TransactionsModel d1;

  late List<TransactionsModel> allTxs;
  late Map<String, TransactionsModel> byTid;
  late Map<String, List<TransactionsModel>> byPid;
  late Map<String, Map<String, TransactionsModel>> byRid;

  setUp(() {
    r1 = _tx(tid: 'r1', pid: '0', rid: '0', rrId: 10);
    c1 = _tx(tid: 'c1', pid: 'r1', rid: 'r1', rrId: 20);
    c2 = _tx(tid: 'c2', pid: 'r1', rid: 'r1', rrId: 10);
    gc1 = _tx(tid: 'gc1', pid: 'c1', rid: 'r1', rrId: 10);
    gc2 = _tx(tid: 'gc2', pid: 'c1', rid: 'r1', rrId: 30);
    gc3 = _tx(tid: 'gc3', pid: 'c2', rid: 'r1', rrId: 20);

    r2 = _tx(tid: 'r2', pid: '0', rid: '0', rrId: 99);
    d1 = _tx(tid: 'd1', pid: 'r2', rid: 'r2', rrId: 99);

    allTxs = [r1, c1, c2, gc1, gc2, gc3, r2, d1];
    byTid = {for (final tx in allTxs) tx.tid: tx};

    byPid = {};
    for (final tx in allTxs) {
      if (tx.pid.isNotEmpty && tx.pid != '0') {
        (byPid[tx.pid] ??= []).add(tx);
      }
    }

    byRid = {};
    for (final tx in allTxs) {
      final treeKey = tx.isRoot ? tx.tid : tx.rid;
      (byRid[treeKey] ??= {})[tx.tid] = tx;
    }
  });

  group('getCloseTargetParent', () {
    test('returns null when tx is a root', () {
      expect(TransactionsHelper.getCloseTargetParent(r1, txsMap: byTid), isNull);
    });

    test('returns null when both txs and txsMap are null', () {
      expect(TransactionsHelper.getCloseTargetParent(gc1), isNull);
    });

    test('returns furthest matching ancestor rather than furthest root', () {
      // ggc (rrId: 10) -> parent c2 (rrId: 10) -> root r1 (rrId: 10)
      final ggc = _tx(tid: 'ggc', pid: 'c2', rid: 'r1', rrId: 10);
      final mapWithGgc = {...byTid, 'ggc': ggc};

      final target = TransactionsHelper.getCloseTargetParent(ggc, txsMap: mapWithGgc);
      expect(target?.tid, 'r1'); // Closest matching ancestor (c2), NOT r1
    });

    test('skips non-matching intermediate parent and finds root', () {
      // gc1 (rrId: 10) -> c1 (rrId: 20, skip) -> r1 (rrId: 10, match!)
      final target = TransactionsHelper.getCloseTargetParent(gc1, txsMap: byTid);
      expect(target?.tid, 'r1');
    });

    test('falls back to rid root when intermediate parent is missing from map', () {
      final brokenMap = Map<String, TransactionsModel>.from(byTid)..remove('c1');

      // gc1 -> c1 (missing!) -> falls back to r1 via rid
      final target = TransactionsHelper.getCloseTargetParent(gc1, txsMap: brokenMap);
      expect(target?.tid, 'r1');
    });

    test('returns null when no ancestor or root has matching rrId', () {
      // gc2 has rrId 30; c1 is 20, r1 is 10
      final target = TransactionsHelper.getCloseTargetParent(gc2, txsMap: byTid);
      expect(target, isNull);
    });

    test('handles sentinel "0" pid and rid safely without throwing', () {
      final orphan = _tx(tid: 'o1', pid: '0', rid: '0', rrId: 10);
      expect(TransactionsHelper.getCloseTargetParent(orphan, txsMap: byTid), isNull);
    });

    test('works when passing raw txs list instead of txsMap', () {
      final target = TransactionsHelper.getCloseTargetParent(gc1, txs: allTxs);
      expect(target?.tid, 'r1');
    });
  });

  group('collectRootTreeLeaves', () {
    test('returns all non-root transactions in the specified root tree', () {
      final leaves = TransactionsHelper.collectRootTreeLeaves(r1, txsMap: byRid['r1']);
      expect(leaves.map((e) => e.tid), unorderedEquals(['c1', 'c2', 'gc1', 'gc2', 'gc3']));
    });

    test('filters to matching rid when full txs list is passed', () {
      final leaves = TransactionsHelper.collectRootTreeLeaves(r2, txs: allTxs);
      expect(leaves.map((e) => e.tid), ['d1']);
    });

    test('returns empty list when both txs and txsMap are null', () {
      expect(TransactionsHelper.collectRootTreeLeaves(r1), isEmpty);
    });
  });

  group('collectTerminalLeaves & collectDirectLeaves', () {
    test('returns only terminal leaf descendants under parent using childrenMap', () {
      final leaves = TransactionsHelper.collectTerminalLeaves(r1, childrenMap: byPid);
      expect(leaves.map((e) => e.tid), ['gc1', 'gc2', 'gc3']);
    });

    test('returns only terminal leaves under an intermediate branch node', () {
      final leaves = TransactionsHelper.collectTerminalLeaves(c1, childrenMap: byPid);
      expect(leaves.map((e) => e.tid), ['gc1', 'gc2']);
    });

    test('returns empty list when parent itself is already a terminal leaf', () {
      final leaves = TransactionsHelper.collectTerminalLeaves(gc1, childrenMap: byPid);
      expect(leaves, isEmpty);
    });

    test('works when building childrenMap from raw txs list', () {
      final leaves = TransactionsHelper.collectTerminalLeaves(r1, txs: allTxs);
      expect(leaves.map((e) => e.tid), ['gc1', 'gc2', 'gc3']);
    });
  });

  group('collectAllRoots', () {
    test('returns all roots from indexed rootMap', () {
      final roots = TransactionsHelper.collectAllRoots(rootMap: byRid);
      expect(roots.map((e) => e.tid), unorderedEquals(['r1', 'r2']));
    });

    test('returns all roots from raw txs list fallback', () {
      final roots = TransactionsHelper.collectAllRoots(txs: allTxs);
      expect(roots.map((e) => e.tid), unorderedEquals(['r1', 'r2']));
    });

    test('returns empty list when no inputs are provided', () {
      expect(TransactionsHelper.collectAllRoots(), isEmpty);
    });
  });

  group('collectAllTerminalLeaves', () {
    test('returns all terminal leaves across all trees using txsMap and childrenMap', () {
      final leaves = TransactionsHelper.collectAllTerminalLeaves(txsMap: byTid, childrenMap: byPid);
      expect(leaves.map((e) => e.tid), unorderedEquals(['gc1', 'gc2', 'gc3', 'd1']));
    });

    test('returns identical result using fallback txs list without childrenMap', () {
      final leaves = TransactionsHelper.collectAllTerminalLeaves(txs: allTxs);
      expect(leaves.map((e) => e.tid), unorderedEquals(['gc1', 'gc2', 'gc3', 'd1']));
    });

    test('excludes childless roots from terminal leaves', () {
      final soloRoot = _tx(tid: 'r3', pid: '0', rid: '0');
      final leaves = TransactionsHelper.collectAllTerminalLeaves(txs: [soloRoot]);
      expect(leaves, isEmpty);
    });
  });

  group('collectAllLeaves', () {
    test('returns all descendants (branches and leaves) under parent', () {
      final descendants = TransactionsHelper.collectAllLeaves(r1, childrenMap: byPid);
      expect(descendants.map((e) => e.tid), ['c1', 'gc1', 'gc2', 'c2', 'gc3']);
    });

    test('works with fallback txs list', () {
      final descendants = TransactionsHelper.collectAllLeaves(c1, txs: allTxs);
      expect(descendants.map((e) => e.tid), ['gc1', 'gc2']);
    });

    test('returns empty list when parent has no children', () {
      expect(TransactionsHelper.collectAllLeaves(gc2, childrenMap: byPid), isEmpty);
    });
  });

  group('collectInBetweenLeaves', () {
    test('collects ascendants from start up to and including end', () {
      // gc1 -> c1 -> r1
      final path = TransactionsHelper.collectInBetweenLeaves(gc1, r1, txsMap: byTid);
      expect(path.map((e) => e.tid), ['c1', 'r1']);
    });

    test('stops at intermediate end node without continuing to root', () {
      final path = TransactionsHelper.collectInBetweenLeaves(gc1, c1, txsMap: byTid);
      expect(path.map((e) => e.tid), ['c1']);
    });

    test('returns empty list when start is already root', () {
      final path = TransactionsHelper.collectInBetweenLeaves(r1, r1, txsMap: byTid);
      expect(path, isEmpty);
    });

    test('stops gracefully when parent link is missing in map', () {
      final brokenMap = Map<String, TransactionsModel>.from(byTid)..remove('c1');
      final path = TransactionsHelper.collectInBetweenLeaves(gc1, r1, txsMap: brokenMap);
      expect(path, isEmpty);
    });

    test('works with raw txs list fallback', () {
      final path = TransactionsHelper.collectInBetweenLeaves(gc3, r1, txs: allTxs);
      expect(path.map((e) => e.tid), ['c2', 'r1']);
    });
  });

  group('getLeaf', () {
    test('returns immediate direct children using childrenMap', () {
      final children = TransactionsHelper.getLeaf(r1, childrenMap: byPid);
      expect(children.map((e) => e.tid), ['c1', 'c2']);
    });
    test('returns immediate direct children using fallback txsMap', () {
      final children = TransactionsHelper.getLeaf(c1, txsMap: byTid);
      expect(children.map((e) => e.tid), ['gc1', 'gc2']);
    });
    test('returns empty list when node has no children', () {
      expect(TransactionsHelper.getLeaf(gc1, childrenMap: byPid), isEmpty);
    });
  });
}
