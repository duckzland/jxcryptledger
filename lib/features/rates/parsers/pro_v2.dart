import 'dart:convert';
import 'package:decimal/decimal.dart';

import '../../../core/extensions/decimals.dart';
import '../../../core/runtime/locators/client.dart';
import '../../cryptos/service.dart';
import '../model.dart';
import 'result.dart';

RatesParserResult parseRatesJsonV2(String body) {
  final data = jsonDecode(body);

  // NOT SAFE FOR COMPUTE!
  final cryptoService = locator<CryptosService>();

  final dataNode = data['data'];
  if (dataNode == null) {
    throw FormatException('Missing data node');
  }

  final sourceSymbol = dataNode['symbol'] as String?;
  final sourceIdStr = dataNode['id']?.toString();
  final sourceAmount = (dataNode['amount'] as Object?).toDecimal();

  if (sourceSymbol == null || sourceIdStr == null || sourceAmount == null) {
    throw FormatException('Missing source fields');
  }

  final sourceId = int.parse(sourceIdStr);

  final quotes = dataNode['quote'] as Map<String, dynamic>?;

  if (quotes == null) {
    throw FormatException('Missing quote array');
  }

  final List<RatesModel> rates = [];

  for (final entry in quotes.entries) {
    final q = entry.value as Map<String, dynamic>;
    final parsedId = int.tryParse(entry.key);

    final targetId = parsedId ?? cryptoService.getIdBySymbol(entry.key);
    final targetSymbol = parsedId != null ? cryptoService.getSymbol(parsedId) : entry.key;
    final targetAmount = (q['price'] as Object?).toDecimal();

    if (targetId == null || targetAmount == null || targetSymbol == null) {
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
