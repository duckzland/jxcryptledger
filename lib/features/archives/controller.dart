import '../../app/exceptions.dart';
import '../../core/abstracts/controller.dart';
import '../../core/mixins/controllers/exportable.dart';
import '../../core/mixins/controllers/id_generator.dart';
import '../../core/runtime/locator.dart';
import '../../system/settings/controller.dart';
import '../transactions/controller.dart';
import '../watchboard/panels/controller.dart';
import '../watchers/controller.dart';
import 'model.dart';
import 'repository.dart';

class ArchivesController extends CoreBaseController<ArchivesModel, ArchivesRepository>
    with
        CoreMixinsControllersIdGenerator<ArchivesModel, ArchivesRepository>,
        CoreMixinsControllersExportable<ArchivesModel, ArchivesRepository> {
  ArchivesController(super.repo);

  final TransactionsController _txController = locator<TransactionsController>();
  final PanelsController _pxController = locator<PanelsController>();
  final WatchersController _wxController = locator<WatchersController>();
  final SettingsController _sxController = locator<SettingsController>();

  Future<void> restoreData(ArchivesModel ax) async {
    switch (ax.typeEnum) {
      case ArchivesDataType.transactions:
        await _txController.importDatabase(ax.data);
      case ArchivesDataType.watchboards:
        await _pxController.importDatabase(ax.data);
      case ArchivesDataType.watchers:
        await _wxController.importDatabase(ax.data);
      case ArchivesDataType.settings:
        await _sxController.importDatabase(ax.data);
    }

    load();
  }

  Future<String> populateData(ArchivesDataType type) async {
    try {
      switch (type) {
        case ArchivesDataType.transactions:
          return await _txController.exportDatabase();
        case ArchivesDataType.watchboards:
          return await _pxController.exportDatabase();
        case ArchivesDataType.watchers:
          return await _wxController.exportDatabase();
        case ArchivesDataType.settings:
          return await _sxController.exportDatabase();
      }
    } catch (_) {
      throw ValidationException(AppErrorCode.archiveInvalidType, "Invalid type", "Invalid archive type detected");
    }
  }
}
