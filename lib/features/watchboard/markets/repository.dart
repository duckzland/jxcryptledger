import '../../../core/abstracts/repository.dart';
import '../../../core/mixins/repositories/id_generator.dart';
import 'model.dart';

class MarketsRepository extends CoreBaseRepository<MarketsModel> with CoreMixinsRepositoriesIdGenerator<MarketsModel> {
  @override
  String get boxName => 'markets_box';
}
