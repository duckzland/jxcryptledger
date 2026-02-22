import 'package:decimal/decimal.dart';
import 'package:jxcryptledger/core/utils.dart';

enum TransactionStatus { active, partial, closed, unknown }

class TransactionsModel {
  final String tid;
  final String rid;
  final String pid;
  final double srAmount;
  final int srId;
  final double rrAmount;
  final int rrId;
  final double balance;
  final int status;
  final int timestamp;
  final Map<String, dynamic> meta;

  const TransactionsModel({
    required this.tid,
    required this.rid,
    required this.pid,
    required this.srAmount,
    required this.srId,
    required this.rrAmount,
    required this.rrId,
    required this.balance,
    required this.status,
    required this.timestamp,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'tid': tid,
      'rid': rid,
      'pid': pid,
      'srAmount': srAmount,
      'srId': srId,
      'rrAmount': rrAmount,
      'rrId': rrId,
      'balance': balance,
      'status': status,
      'timestamp': timestamp,
      'meta': meta,
    };
  }

  factory TransactionsModel.fromMap(Map<String, dynamic> map) {
    return TransactionsModel(
      tid: map['tid'] as String,
      rid: map['rid'] as String,
      pid: map['pid'] as String,
      srAmount: (map['srAmount'] as num).toDouble(),
      srId: map['srId'] as int,
      rrAmount: (map['rrAmount'] as num).toDouble(),
      rrId: map['rrId'] as int,
      balance: (map['rrAmount'] as num).toDouble(),
      status: map['rrId'] as int,
      timestamp: map['timestamp'] as int,
      meta: Map<String, dynamic>.from(map['meta'] ?? {}),
    );
  }

  TransactionsModel copyWith({
    String? tid,
    String? rid,
    String? pid,
    double? srAmount,
    int? srId,
    double? rrAmount,
    int? rrId,
    int? timestamp,
    double? balance,
    int? status,
    Map<String, dynamic>? meta,
  }) {
    return TransactionsModel(
      tid: tid ?? this.tid,
      rid: rid ?? this.rid,
      pid: pid ?? this.pid,
      srAmount: srAmount ?? this.srAmount,
      srId: srId ?? this.srId,
      rrAmount: rrAmount ?? this.rrAmount,
      rrId: rrId ?? this.rrId,
      balance: balance ?? this.balance,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }

  TransactionStatus get statusEnum {
    switch (status) {
      case 1:
        return TransactionStatus.active;
      case 2:
        return TransactionStatus.partial;
      case 3:
        return TransactionStatus.closed;
      default:
        return TransactionStatus.unknown;
    }
  }

  String get statusText {
    switch (statusEnum) {
      case TransactionStatus.active:
        return 'Active';
      case TransactionStatus.partial:
        return 'Partial';
      case TransactionStatus.closed:
        return 'Closed';
      case TransactionStatus.unknown:
        return 'Unknown';
    }
  }

  String get timestampAsDate {
    final isMilliseconds = timestamp > 2000000000;

    final date = isMilliseconds
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String get srAmountText => Utils.formatSmartDouble(srAmount);
  String get rrAmountText => Utils.formatSmartDouble(rrAmount);
  String get balanceText => Utils.formatSmartDouble(balance);
  String get rateText => Utils.formatSmartDouble(rateDouble);

  Decimal get rate => Decimal.parse((rrAmount / srAmount).toDouble().toString());
  double get rateDouble => (rrAmount / srAmount).toDouble();
}
