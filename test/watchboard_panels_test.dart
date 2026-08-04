import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxledger/features/watchboard/panels/adapter.dart';
import 'package:jxledger/features/watchboard/panels/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Hive.init('./test/database');
  Hive.registerAdapter(PanelsAdapter());

  group('Watchboard panels', () {
    test('persists Decimal rate values without lossy double conversion', () async {
      final box = await Hive.openBox<PanelsModel>('panels_precision_test');
      await box.clear();

      final panel = PanelsModel(
        tid: 'panel-1',
        srAmount: Decimal.parse('100.1234567890123456789'),
        srId: 1,
        rrId: 2,
        digit: 8,
        rate: Decimal.parse('63.8281234567890123456'),
        order: 1,
        meta: {'oldRate': '1.0'},
      );

      panel.setRate(Decimal.parse('63.8281234567890123456'));
      await box.put(panel.uuid, panel);

      final stored = box.get(panel.uuid)!;
      expect(stored.srAmount, Decimal.parse('100.1234567890123456789'));
      expect(stored.rate, Decimal.parse('63.8281234567890123456'));

      panel.setRate(Decimal.parse('63.8281234567890123456000000001'));
      await box.put(panel.uuid, panel);

      final updated = box.get(panel.uuid)!;
      expect(updated.rate, Decimal.parse('63.8281234567890123456000000001'));
    });
  });
}
