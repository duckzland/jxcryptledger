import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'model.dart';

class RatesParserResult {
  final List<RatesModel> rates;

  RatesParserResult(this.rates);
}

RatesParserResult parseRatesJson(String body) {
  final data = jsonDecode(body);

  final dataNode = data['data'];
  if (dataNode == null) {
    throw const FormatException('Missing data node');
  }

  final sourceSymbol = dataNode['symbol'] as String?;
  final sourceIdStr = dataNode['id']?.toString();
  final sourceAmount = (dataNode['amount'] as num?)?.toDouble();

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
    final priceRaw = q['price'];

    if (targetSymbol == null || targetId == null || priceRaw == null) {
      continue;
    }

    // price can be string or number
    final priceStr = priceRaw.toString();
    final targetAmount = Decimal.parse(priceStr);

    rates.add(
      RatesModel(
        sourceSymbol: sourceSymbol,
        sourceId: sourceId,
        sourceAmount: Decimal.parse(sourceAmount.toString()),
        targetSymbol: targetSymbol,
        targetId: targetId,
        targetAmount: targetAmount,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  return RatesParserResult(rates);
}
