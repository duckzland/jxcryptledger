class TransactionModel {
  /// Transaction ID (UUID)
  final String tid;

  /// Root ID (UUID or "0" if this is the root)
  final String rid;

  /// Parent ID (UUID or "0" if this is the root)
  final String pid;

  /// Source amount (float, can be negative)
  final double srAmount;

  /// Source coin ID (CMC ID, numeric > 0)
  final int srId;

  /// Result amount (float, can be negative)
  final double rrAmount;

  /// Result coin ID (CMC ID, numeric > 0)
  final int rrId;

  /// Timestamp (Unix epoch)
  final int timestamp;

  /// Generic metadata (JSON-like map)
  final Map<String, dynamic> meta;

  const TransactionModel({
    required this.tid,
    required this.rid,
    required this.pid,
    required this.srAmount,
    required this.srId,
    required this.rrAmount,
    required this.rrId,
    required this.timestamp,
    required this.meta,
  });

  /// Convert to Map for storage or encryption
  Map<String, dynamic> toMap() {
    return {
      'tid': tid,
      'rid': rid,
      'pid': pid,
      'srAmount': srAmount,
      'srId': srId,
      'rrAmount': rrAmount,
      'rrId': rrId,
      'timestamp': timestamp,
      'meta': meta,
    };
  }

  /// Create from Map
  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      tid: map['tid'] as String,
      rid: map['rid'] as String,
      pid: map['pid'] as String,
      srAmount: (map['srAmount'] as num).toDouble(),
      srId: map['srId'] as int,
      rrAmount: (map['rrAmount'] as num).toDouble(),
      rrId: map['rrId'] as int,
      timestamp: map['timestamp'] as int,
      meta: Map<String, dynamic>.from(map['meta'] ?? {}),
    );
  }

  /// Copy with modifications
  TransactionModel copyWith({
    String? tid,
    String? rid,
    String? pid,
    double? srAmount,
    int? srId,
    double? rrAmount,
    int? rrId,
    int? timestamp,
    Map<String, dynamic>? meta,
  }) {
    return TransactionModel(
      tid: tid ?? this.tid,
      rid: rid ?? this.rid,
      pid: pid ?? this.pid,
      srAmount: srAmount ?? this.srAmount,
      srId: srId ?? this.srId,
      rrAmount: rrAmount ?? this.rrAmount,
      rrId: rrId ?? this.rrId,
      timestamp: timestamp ?? this.timestamp,
      meta: meta ?? Map<String, dynamic>.from(this.meta),
    );
  }
}
