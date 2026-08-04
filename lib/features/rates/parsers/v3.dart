import 'dart:convert';
import 'package:decimal/decimal.dart';

import '../../../core/extensions/decimals.dart';
import '../model.dart';
import 'result.dart';

RatesParserResult parseRatesJsonV3(String body) {
  final data = jsonDecode(body);

  final dataNode = data['data'];
  if (dataNode == null) {
    throw const FormatException('Missing data node');
  }

  final sourceSymbol = dataNode['symbol'] as String?;
  final sourceIdStr = dataNode['id']?.toString();
  final sourceAmount = (dataNode['amount'] as Object?).toDecimal();

  if (sourceSymbol == null || sourceIdStr == null || sourceAmount == null) {
    throw const FormatException('Missing source fields');
  }

  final sourceId = int.parse(sourceIdStr);

  final quotes = dataNode['quote'] as List<dynamic>?;

  if (quotes == null) {
    throw const FormatException('Missing quote array');
  }

  final List<RatesModel> rates = [];

  for (final q in quotes) {
    final targetSymbol = q['symbol'] as String?;
    final targetId = q['cryptoId'] as int?;
    final targetAmount = (q['price'] as Object?).toDecimal();

    if (targetSymbol == null || targetId == null || targetAmount == null) {
      continue;
    }

    final reversed = (Decimal.one / targetAmount).toDecimal(scaleOnInfinitePrecision: 18);

    rates.add(
      RatesModel(
        sourceSymbol: sourceSymbol,
        sourceId: sourceId,
        sourceAmount: sourceAmount,
        targetSymbol: targetSymbol,
        targetId: targetId,
        targetAmount: targetAmount,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    );

    rates.add(
      RatesModel(
        sourceAmount: sourceAmount,
        sourceSymbol: targetSymbol,
        sourceId: targetId,
        targetSymbol: sourceSymbol,
        targetId: sourceId,
        targetAmount: reversed,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  return RatesParserResult(rates);
}
