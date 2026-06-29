import '../../app/exceptions.dart';
import '../../core/abstracts/controller.dart';
import 'model.dart';
import 'repository.dart';
import 'service.dart';

class CryptosController extends CoreBaseController<CryptosModel, CryptosRepository> {
  final CryptosService service;

  CryptosController(super.repo, this.service);

  bool get isFetching => service.isFetching;

  @override
  void emitterAction(String action) async {
    if (action == "cryptos_refresh_start") {
      debounceNotify();
    }

    if (action == repo.boxName) {
      load();
    }
  }

  List<CryptosModel> filter(String query) {
    return repo.filter(query);
  }

  Map<int, String> getSymbolMap() {
    return repo.getSymbolMap();
  }

  void generateSymbolMap() {
    repo.onAction();
    repo.getSymbolMap();
  }

  String? getSymbol(int id) {
    return repo.getSymbol(id);
  }

  Future<bool> fetch() async {
    try {
      final success = await service.fetch();

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
