import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/features/rates/adapter.dart';
import 'package:jxledger/features/rates/model.dart';
import 'package:jxledger/features/rates/parsers/v3.dart';
import 'package:jxledger/features/rates/repository.dart';

import 'faker/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Hive.init('./test/database');
  Hive.registerAdapter(RatesAdapter());

  group('Rates persistence', () {
    late Box<RatesModel> box;
    late RatesRepository repo;

    setUp(() async {
      box = await Hive.openBox<RatesModel>('rates_test');
      await box.clear();
      repo = RatesRepository();
      repo.box = HiveBoxFaker<RatesModel>('rates_test', hiveBoxOverride: box);
    });

    test('stores parsed rates without rounding their Decimal values', () async {
      final body = jsonEncode({
        'data': {
          'symbol': 'BTC',
          'id': 1,
          'amount': '1.2345678901234567890123456789',
          'quote': [
            {'symbol': 'USD', 'cryptoId': 2, 'price': '3.1415926535897932384626433832795'},
          ],
        },
      });

      final parsed = parseRatesJsonV3(body);
      final directRate = parsed.rates.firstWhere((rate) => rate.sourceId == 1 && rate.targetId == 2);
      final reversedRate = parsed.rates.firstWhere((rate) => rate.sourceId == 2 && rate.targetId == 1);

      await repo.add(directRate);
      await repo.add(reversedRate);

      final storedDirect = repo.get('1-2')!;
      final storedReverse = repo.get('2-1')!;

      expect(storedDirect.sourceAmount, Decimal.parse('1.2345678901234567890123456789'));
      expect(storedDirect.targetAmount, Decimal.parse('3.1415926535897932384626433832795'));

      expect(storedReverse.sourceAmount, Decimal.parse('1.2345678901234567890123456789'));
      expect(
        storedReverse.targetAmount,
        (Decimal.one / Decimal.parse('3.1415926535897932384626433832795')).toDecimal(scaleOnInfinitePrecision: 100),
      );
    });
  });
}
