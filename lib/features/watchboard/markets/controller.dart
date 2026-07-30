import '../../../core/abstracts/controller.dart';
import '../../../core/mixins/controllers/id_generator.dart';
import 'model.dart';
import 'repository.dart';

class MarketsController extends CoreBaseController<MarketsModel, MarketsRepository>
    with CoreMixinsControllersIdGenerator<MarketsModel, MarketsRepository> {
  MarketsController(super.repo);

  bool isBothEqual(MarketsModel a, MarketsModel b) {
    return a.tid == b.tid &&
        a.name == b.name &&
        a.symbol == b.symbol &&
        a.rank == b.rank &&
        a.isInfinite == b.isInfinite &&
        a.totalSupply == b.totalSupply &&
        a.maxSupply == b.maxSupply &&
        a.price == b.price &&
        a.volume24h == b.volume24h &&
        a.volumeChange24h == b.volumeChange24h &&
        a.percent1h == b.percent1h &&
        a.percent24h == b.percent24h &&
        a.percent7d == b.percent7d &&
        a.percent30d == b.percent30d &&
        a.percent60d == b.percent60d &&
        a.percent90d == b.percent90d &&
        a.marketCap == b.marketCap &&
        a.dominance == b.dominance &&
        a.meta.length == b.meta.length &&
        a.meta.keys.every((k) => b.meta.containsKey(k) && a.meta[k] == b.meta[k]);
  }
}
