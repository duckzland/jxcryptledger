import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jxledger/app/exceptions.dart';
import 'package:jxledger/features/transactions/model.dart';
import 'package:jxledger/features/transactions/rules/import.dart';

void main() {
  TransactionsModel transaction({
    required String tid,
    required String pid,
    required String rid,
    required String srAmount,
    required int srId,
    required String rrAmount,
    required int rrId,
    required String balance,
    required TransactionStatus status,
    required bool closable,
  }) {
    return TransactionsModel(
      tid: tid,
      pid: pid,
      rid: rid,
      srAmount: Decimal.parse(srAmount),
      srId: srId,
      rrAmount: Decimal.parse(rrAmount),
      rrId: rrId,
      balance: Decimal.parse(balance),
      status: status.index,
      closable: closable,
      timestamp: 1,
      meta: const {},
    );
  }

  List<Map<String, dynamic>> transactions({required bool returnedTransactionIsClosed}) {
    return [
      transaction(
        tid: 'root',
        pid: '0',
        rid: '0',
        srAmount: '1000',
        srId: 1,
        rrAmount: '1000',
        rrId: 1,
        balance: '900',
        status: TransactionStatus.active,
        closable: true,
      ).toJson(),
      transaction(
        tid: 'parent',
        pid: 'root',
        rid: 'root',
        srAmount: '100',
        srId: 1,
        rrAmount: '100',
        rrId: 2,
        balance: '100',
        status: TransactionStatus.partial,
        closable: false,
      ).toJson(),
      transaction(
        tid: 'branch',
        pid: 'parent',
        rid: 'root',
        srAmount: '100',
        srId: 2,
        rrAmount: '150',
        rrId: 3,
        balance: '0',
        status: TransactionStatus.inactive,
        closable: false,
      ).toJson(),
      transaction(
        tid: 'returned',
        pid: 'branch',
        rid: 'root',
        srAmount: '150',
        srId: 3,
        rrAmount: '150',
        rrId: 2,
        balance: '0',
        status: returnedTransactionIsClosed ? TransactionStatus.closed : TransactionStatus.active,
        closable: true,
      ).toJson(),
      transaction(
        tid: 'profit',
        pid: 'parent',
        rid: 'root',
        srAmount: '50',
        srId: 2,
        rrAmount: '50',
        rrId: 3,
        balance: '50',
        status: TransactionStatus.active,
        closable: false,
      ).toJson(),
    ];
  }

  test('accepts child spending funded by a closed descendant return', () {
    final rule = TransactionsRulesImport();

    expect(() => rule.validateJson(jsonEncode(transactions(returnedTransactionIsClosed: true))), returnsNormally);
  });

  test('rejects child spending that exceeds original output without a return', () {
    final rule = TransactionsRulesImport();

    expect(
      () => rule.validateJson(jsonEncode(transactions(returnedTransactionIsClosed: false))),
      throwsA(isA<ValidationException>().having((error) => error.code, 'code', AppErrorCode.txImportChildAmountSumExceeded)),
    );
  });
}
