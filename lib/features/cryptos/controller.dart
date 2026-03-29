import '../../core/abstracts/controller.dart';
import '../../app/exceptions.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class CryptosController extends CoreBaseController<CryptosModel, int, CryptosRepository> {
  final CryptosService _service;

  CryptosController(super.repo, this._service);

  bool get isFetching => _service.isFetching;

  @override
  Future<void> init() async {
    await repo.init();
    load();
  }

  Future<void> deleteById(int id) async {
    await repo.deleteById(id);
    load();
  }

  List<CryptosModel> filter(String query) {
    return repo.filter(query);
  }

  Map<int, String> getSymbolMap() {
    return repo.getSymbolMap();
  }

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  CryptosModel? getById(int id) {
    return repo.getById(id);
  }

  Future<bool> fetch() async {
    try {
      final success = await _service.fetch();

      if (success) {
        load();
      }

      return success;
    } on NetworkingException {
      rethrow;
    } catch (e) {
      throw NetworkingException(
        AppErrorCode.netUnknownFailure,
        "CryptosController fetch failed unexpectedly: $e",
        "Unable to update crypto data due to an unexpected error.",
        details: e,
      );
    }
  }
}
