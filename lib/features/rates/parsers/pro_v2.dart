import 'dart:convert';
import 'package:decimal/decimal.dart';

import '../../../core/runtime/locator.dart';
import '../../cryptos/service.dart';
import '../model.dart';
import 'result.dart';

RatesParserResult parseRatesJsonV2(String body) {
  final data = jsonDecode(body);

  // NOT SAFE FOR COMPUTE!
  final cryptoService = locator<CryptosService>();

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

  final quotes = dataNode['quote'] as Map<String, dynamic>?;

  if (quotes == null) {
    throw const FormatException('Missing quote array');
  }

  final List<RatesModel> rates = [];

  for (final entry in quotes.entries) {
    final q = entry.value as Map<String, dynamic>;

    final targetSymbol = entry.key;
    final targetId = cryptoService.getIdBySymbol(entry.key);
    final priceRaw = q['price'];

    if (targetId == null || priceRaw == null) {
      continue;
    }

    final priceStr = priceRaw.toString();
    final targetAmount = Decimal.parse(priceStr);
    final reversed = Decimal.one / targetAmount;

    rates.add(
      RatesModel(
        sourceSymbol: sourceSymbol,
        sourceId: sourceId,
        sourceAmount: Decimal.parse(sourceAmount.toString()),
        targetSymbol: targetSymbol,
        targetId: targetId,
        targetAmount: targetAmount,
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    );

    // Added reversed rates
    rates.add(
      RatesModel(
        sourceAmount: Decimal.parse(sourceAmount.toString()),
        sourceSymbol: targetSymbol,
        sourceId: targetId,
        targetSymbol: sourceSymbol,
        targetId: sourceId,
        targetAmount: reversed.toDecimal(scaleOnInfinitePrecision: 18),
        timestamp: DateTime.now().microsecondsSinceEpoch,
      ),
    );
  }

  return RatesParserResult(rates);
}
