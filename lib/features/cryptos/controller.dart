import '../../core/abstracts/controller.dart';
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

    if (event.boxName == repo.boxName) {
      if (hasCryptos != !repo.isEmpty()) {
        hasCryptos = !repo.isEmpty();
        debounceNotify();
      }
    }

    if (event.op == 0x11) {
      if (event.boxName == "start") {
        if (!isFetching) {
          isFetching = true;
          debounceNotify();
        }
      }

      if (event.boxName == "complete") {
        if (isFetching) {
          isFetching = false;
          debounceNotify();
        }
      }
    }

    super.broadcasterAction(event);
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
    await ipcClient.send(op: 0x11, box: "action");
    isFetching = false;
  }
}
