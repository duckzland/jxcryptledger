import '../../core/abstracts/repository.dart';
import '../../core/log.dart';
import 'model.dart';

class RatesRepository extends CoreBaseRepository<RatesModel> {
  @override
  String get boxName => 'rates_box';

  Future<void> cleanupOldRates({Duration olderThan = const Duration(days: 1)}) async {
    logln('[RATES] Cleaning old rates.');

    final nowEpoch = DateTime.now().microsecondsSinceEpoch;
    final keysToDelete = <dynamic>[];

    for (int i = 0; i < box.length; i++) {
      final rate = box.getAt(i);
      if (rate != null) {
        final ageMs = nowEpoch - rate.timestamp;
        if (ageMs > olderThan.inMilliseconds) {
          keysToDelete.add(box.keyAt(i));
        }
      }
    }

    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }
}
