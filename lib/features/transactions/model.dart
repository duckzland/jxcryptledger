import 'package:decimal/decimal.dart';
import 'package:jxcryptledger/core/utils.dart';

enum TransactionStatus { inactive, active, partial, closed, unknown }

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
  final bool closable;
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
    required this.closable,
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
      'closable': closable,
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
      balance: (map['balance'] as num).toDouble(),
      status: map['status'] as int,
      closable: map['closable'] as bool,
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
    bool? closable,
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
      closable: closable ?? this.closable,
      timestamp: timestamp ?? this.timestamp,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }

  TransactionStatus get statusEnum {
    switch (status) {
      case 0:
        return TransactionStatus.inactive;
      case 1:
        return TransactionStatus.active;
      case 2:
        return TransactionStatus.partial;
      case 4:
        return TransactionStatus.closed;
      default:
        return TransactionStatus.unknown;
    }
  }

  String get statusText {
    switch (statusEnum) {
      case TransactionStatus.active:
        return 'Active';
      case TransactionStatus.inactive:
        return 'Inactive';
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

  Decimal get rate {
    if (srAmount <= 0 || rrAmount <= 0) return Decimal.zero;
    final r = rrAmount / srAmount;
    return Decimal.parse(r.toString());
  }

  double get rateDouble {
    if (srAmount <= 0 || rrAmount <= 0) return 0.0;
    final r = rrAmount / srAmount;
    return r.isFinite ? r : 0.0;
  }

  bool get isActive {
    return statusEnum == TransactionStatus.active;
  }

  bool get isPartial {
    return statusEnum == TransactionStatus.partial;
  }

  bool get isRoot {
    return pid == '0' && rid == '0';
  }

  bool get isLeaf {
    return !isRoot;
  }

  bool get isClosable {
    if (isRoot || !isActive) {
      return false;
    }

    return closable;
  }

  bool get isTradable {
    return (isActive || isPartial) && hasBalance;
  }

  bool get isDeletable {
    return isRoot && isActive;
  }

  bool get isEditable {
    return isActive;
  }

  bool get hasParent {
    return pid != '0';
  }

  bool get hasRoot {
    return rid != '0';
  }

  bool get hasBalance {
    return balance > 0;
  }
}
