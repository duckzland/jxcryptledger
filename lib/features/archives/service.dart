import '../../../core/abstracts/service.dart';
import '../../../core/mixins/services/rateable.dart';
import 'model.dart';
import 'repository.dart';

class ArchivesService extends CoreBaseService<ArchivesModel, ArchivesRepository>
    with CoreMixinsServicesRateable<ArchivesModel, ArchivesRepository> {
  ArchivesService(super.repo);
}
