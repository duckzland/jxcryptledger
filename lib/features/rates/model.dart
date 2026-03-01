import 'package:decimal/decimal.dart';

import '../../core/utils.dart';

class RatesModel {
  final String sourceSymbol;
  final int sourceId;
  final Decimal sourceAmount;

  final String targetSymbol;
  final int targetId;
  final Decimal targetAmount;

  final int timestamp;

  const RatesModel({
    required this.sourceSymbol,
    required this.sourceId,
    required this.sourceAmount,
    required this.targetSymbol,
    required this.targetId,
    required this.targetAmount,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceSymbol': sourceSymbol,
      'sourceId': sourceId,
      'sourceAmount': sourceAmount.toString(),
      'targetSymbol': targetSymbol,
      'targetId': targetId,
      'targetAmount': targetAmount.toString(),
      'timestamp': timestamp,
    };
  }

  factory RatesModel.fromMap(Map<String, dynamic> map) {
    return RatesModel(
      sourceSymbol: map['sourceSymbol'] as String,
      sourceId: map['sourceId'] is int ? map['sourceId'] as int : 0,
      sourceAmount: Decimal.parse(map['sourceAmount'] as String),
      targetSymbol: map['targetSymbol'] as String,
      targetId: map['sourceId'] is int ? map['sourceId'] as int : 0,
      targetAmount: Decimal.parse(map['targetAmount'] as String),
      timestamp: map['timestamp'] != null
          ? Utils.sanitizeTimestamp((map['timestamp'] as num).toInt())
          : DateTime.now().toUtc().microsecondsSinceEpoch,
    );
  }

  RatesModel copyWith({
    String? sourceSymbol,
    int? sourceId,
    Decimal? sourceAmount,
    String? targetSymbol,
    int? targetId,
    Decimal? targetAmount,
    int? timestamp,
  }) {
    return RatesModel(
      sourceSymbol: sourceSymbol ?? this.sourceSymbol,
      sourceId: sourceId ?? this.sourceId,
      sourceAmount: sourceAmount ?? this.sourceAmount,
      targetSymbol: targetSymbol ?? this.targetSymbol,
      targetId: targetId ?? this.targetId,
      targetAmount: targetAmount ?? this.targetAmount,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  String get rateText => Utils.formatSmartDouble(rateDouble);

  Decimal get rate {
    if (sourceAmount <= Decimal.zero || targetAmount <= Decimal.zero) {
      return Decimal.zero;
    }

    return (targetAmount / sourceAmount).toDecimal(scaleOnInfinitePrecision: 8);
  }

  double get rateDouble {
    final double s = sourceAmount.toDouble();
    final double t = targetAmount.toDouble();

    if (s <= 0 || t <= 0) return 0.0;

    final double r = s / t;

    return r.isFinite ? r : 0.0;
  }
}
