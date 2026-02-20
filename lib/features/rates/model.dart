import 'package:decimal/decimal.dart';

class RatesModel {
  final String sourceSymbol;
  final int sourceId;
  final Decimal sourceAmount;

  final String targetSymbol;
  final int targetId;
  final Decimal targetAmount;

  const RatesModel({
    required this.sourceSymbol,
    required this.sourceId,
    required this.sourceAmount,
    required this.targetSymbol,
    required this.targetId,
    required this.targetAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'sourceSymbol': sourceSymbol,
      'sourceId': sourceId,
      'sourceAmount': sourceAmount.toString(),
      'targetSymbol': targetSymbol,
      'targetId': targetId,
      'targetAmount': targetAmount.toString(),
    };
  }

  factory RatesModel.fromMap(Map<String, dynamic> map) {
    return RatesModel(
      sourceSymbol: map['sourceSymbol'] as String,
      sourceId: map['sourceId'] as int,
      sourceAmount: Decimal.parse(map['sourceAmount'] as String),
      targetSymbol: map['targetSymbol'] as String,
      targetId: map['targetId'] as int,
      targetAmount: Decimal.parse(map['targetAmount'] as String),
    );
  }

  RatesModel copyWith({
    String? sourceSymbol,
    int? sourceId,
    Decimal? sourceAmount,
    String? targetSymbol,
    int? targetId,
    Decimal? targetAmount,
  }) {
    return RatesModel(
      sourceSymbol: sourceSymbol ?? this.sourceSymbol,
      sourceId: sourceId ?? this.sourceId,
      sourceAmount: sourceAmount ?? this.sourceAmount,
      targetSymbol: targetSymbol ?? this.targetSymbol,
      targetId: targetId ?? this.targetId,
      targetAmount: targetAmount ?? this.targetAmount,
    );
  }
}
