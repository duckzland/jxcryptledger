import '../../../core/abstracts/service.dart';
import '../../../core/mixins/services/rateable.dart';
import 'model.dart';
import 'repository.dart';

class TransactionsService extends CoreBaseService<TransactionsModel, TransactionsRepository>
    with CoreMixinsServicesRateable<TransactionsModel, TransactionsRepository> {
  TransactionsService(super.repo);
}
