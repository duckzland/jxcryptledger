import '../../core/abstracts/controller.dart';
import '../../core/ipc/action.dart';
import '../../core/ipc/event.dart';
import 'model.dart';
import 'repository.dart';

class CryptosController extends CoreBaseController<CryptosModel, CryptosRepository> {
  CryptosController(super.repo);

  late bool isFetching;
  late bool hasCryptos;

  @override
  Future<void> init() async {
    super.init();

    isFetching = false;
    hasCryptos = !repo.isEmpty();
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    super.broadcasterAction(event);

    if (event.action == repo.boxName) {
      if (hasCryptos != !repo.isEmpty()) {
        hasCryptos = !repo.isEmpty();
        debounceNotify();
      }
    }

    if (event.actionCode == CoreIpcAction.refreshCryptos) {
      if (event.action == "start") {
        if (!isFetching) {
          isFetching = true;
          debounceNotify();
        }
      }

      if (event.action == "complete") {
        if (isFetching) {
          isFetching = false;
          debounceNotify();
        }
      }
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

  Future<void> fetch() async {
    isFetching = true;
    await ipcClient.send(op: CoreIpcAction.refreshCryptos, action: "action");
    isFetching = false;
  }
}
