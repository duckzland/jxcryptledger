import '../../../core/abstracts/service.dart';
import '../../../core/mixins/services/rateable.dart';
import 'model.dart';
import 'repository.dart';

class PanelsService extends CoreBaseService<PanelsModel, PanelsRepository> with CoreMixinsServicesRateable<PanelsModel, PanelsRepository> {
  PanelsService(super.repo);

  @override
  Future<void> processNewRate(PanelsModel tx, double newRate) async {
    if (newRate != tx.rate) {
      tx.setRate(newRate);
      await repo.update(tx);
    }
  }
}
