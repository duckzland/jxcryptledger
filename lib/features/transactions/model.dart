import 'package:decimal/decimal.dart';
import '../../app/exceptions.dart';
import '../../core/abstracts/model.dart';
import '../../core/utils.dart';

enum TransactionStatus { inactive, active, partial, closed, unknown }

class TransactionsModel extends CoreBaseModel<String> {
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

  @override
  String get uuid => tid;

  TransactionsModel({
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
  }) {
    // --- Basic ID checks ---
    if (tid.isEmpty) {
      throw ValidationException(AppErrorCode.txBasicInvalidTid, "tid cannot be empty.", "Please enter a transaction ID.");
    }
    if (tid == '0') {
      throw ValidationException(AppErrorCode.txBasicInvalidTid, "tid cannot be '0'.", "This transaction ID is not allowed.");
    }

    if (rid.isEmpty) {
      throw ValidationException(AppErrorCode.txBasicInvalidRid, "rid cannot be empty.", "Please enter a reference ID.");
    }
    if (pid.isEmpty) {
      throw ValidationException(AppErrorCode.txBasicInvalidPid, "pid cannot be empty.", "Please enter a parent reference.");
    }

    // --- Root relationship ---
    final isRidRoot = rid == '0';
    final isPidRoot = pid == '0';
    if (isRidRoot != isPidRoot) {
      throw ValidationException(
        AppErrorCode.txBasicInvalidRootRelation,
        "Invalid root relationship: rid=$rid pid=$pid",
        "This transaction’s parent reference is incorrect.",
      );
    }

    // --- Amounts ---
    if (srAmount <= 0) {
      throw ValidationException(
        AppErrorCode.txBasicInvalidSrAmount,
        "srAmount must be > 0 (srAmount=$srAmount).",
        "Source amount must be greater than zero.",
      );
    }
    if (rrAmount <= 0) {
      throw ValidationException(
        AppErrorCode.txBasicInvalidRrAmount,
        "rrAmount must be > 0 (rrAmount=$rrAmount).",
        "Result amount must be greater than zero.",
      );
    }
    if (balance < 0) {
      throw ValidationException(
        AppErrorCode.txBasicInvalidBalance,
        "balance must be >= 0 (balance=$balance).",
        "Balance cannot be negative.",
      );
    }

    // --- Source/Target IDs ---
    if (srId <= 0) {
      throw ValidationException(AppErrorCode.txBasicInvalidSrId, "srId must be > 0 (srId=$srId).", "Please select a valid source account.");
    }
    if (rrId <= 0) {
      throw ValidationException(AppErrorCode.txBasicInvalidRrId, "rrId must be > 0 (rrId=$rrId).", "Please select a valid target account.");
    }
    if (srId == rrId) {
      throw ValidationException(
        AppErrorCode.txBasicSrIdEqualsRrId,
        "srId must not equal rrId (srId=$srId, rrId=$rrId).",
        "Source and target coin must be different.",
      );
    }

    // --- Status ---
    if (status < 0 || status >= TransactionStatus.values.length) {
      throw ValidationException(AppErrorCode.txBasicInvalidStatus, "Invalid status value: $status", "Please select a valid status.");
    }

    // --- Timestamp ---
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;

    if (timestamp <= 0) {
      throw ValidationException(AppErrorCode.txBasicInvalidTimestamp, "timestamp must be > 0 (timestamp=$timestamp).", "Invalid date.");
    }
    if (timestamp > now) {
      throw ValidationException(
        AppErrorCode.txBasicTimestampInFuture,
        "timestamp cannot be in the future (timestamp=$timestamp, now=$now).",
        "Date cannot be in the future.",
      );
    }
  }

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

  Map<String, dynamic> toJson() {
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

  factory TransactionsModel.fromJson(Map<String, dynamic> json) {
    const requiredKeys = [
      'tid',
      'rid',
      'pid',
      'srAmount',
      'srId',
      'rrAmount',
      'rrId',
      'balance',
      'status',
      'closable',
      'timestamp',
      'meta',
    ];

    for (final key in requiredKeys) {
      if (!json.containsKey(key)) {
        throw ValidationException(AppErrorCode.txJsonMissingField, "Missing required field: $key", "Invalid transaction data.");
      }
    }

    if (json['tid'] is! String) {
      throw ValidationException(AppErrorCode.txJsonInvalidTidType, "tid must be a string.", "Invalid transaction data.");
    }
    if (json['rid'] is! String) {
      throw ValidationException(AppErrorCode.txJsonInvalidRidType, "rid must be a string.", "Invalid transaction data.");
    }
    if (json['pid'] is! String) {
      throw ValidationException(AppErrorCode.txJsonInvalidPidType, "pid must be a string.", "Invalid transaction data.");
    }

    if (json['srAmount'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidSrAmountType, "srAmount must be numeric.", "Invalid transaction data.");
    }
    if (json['rrAmount'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidRrAmountType, "rrAmount must be numeric.", "Invalid transaction data.");
    }
    if (json['balance'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidBalanceType, "balance must be numeric.", "Invalid transaction data.");
    }

    if (json['srId'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidSrIdType, "srId must be numeric.", "Invalid transaction data.");
    }
    if (json['rrId'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidRrIdType, "rrId must be numeric.", "Invalid transaction data.");
    }

    if (json['status'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidStatusType, "status must be numeric.", "Invalid transaction data.");
    }

    if (json['timestamp'] is! num) {
      throw ValidationException(AppErrorCode.txJsonInvalidTimestampType, "timestamp must be numeric.", "Invalid transaction data.");
    }

    if (json['closable'] is! bool) {
      throw ValidationException(AppErrorCode.txJsonInvalidClosableType, "closable must be boolean.", "Invalid transaction data.");
    }

    if (json['meta'] is! Map) {
      throw ValidationException(AppErrorCode.txJsonInvalidMetaType, "meta must be a JSON object.", "Invalid transaction data.");
    }

    return TransactionsModel(
      tid: json['tid'] as String,
      rid: json['rid'] as String,
      pid: json['pid'] as String,
      srAmount: (json['srAmount'] as num).toDouble(),
      srId: (json['srId'] as num).toInt(),
      rrAmount: (json['rrAmount'] as num).toDouble(),
      rrId: (json['rrId'] as num).toInt(),
      balance: (json['balance'] as num).toDouble(),
      status: (json['status'] as num).toInt(),
      closable: json['closable'] as bool,
      timestamp: (json['timestamp'] as num).toInt(),
      meta: Map<String, dynamic>.from(json['meta'] as Map),
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

  String get timestampAsFormattedDate {
    return Utils.timestampToFormattedDate(timestamp);
  }

  int get sanitizedTimestamp {
    return Utils.sanitizeTimestamp(timestamp);
  }

  String get srAmountText => Utils.formatSmartDouble(srAmount);
  String get rrAmountText => Utils.formatSmartDouble(rrAmount);
  String get balanceText => Utils.formatSmartDouble(balance);
  String get rateText => Utils.formatSmartDouble(rateDouble);
  String get rateReversedText => Utils.formatSmartDouble(1 / rateDouble);

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
