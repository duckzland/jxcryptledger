import '../../core/abstracts/controller.dart';
import '../../core/ipc/event.dart';
import '../../core/mixins/broadcaster.dart';
import 'model.dart';
import 'repository.dart';

class CryptosController extends CoreBaseController<CryptosModel, CryptosRepository> with CoreMixinsBroadcaster {
  CryptosController(super.repo);

  late bool isFetching;
  late bool hasRates;

  @override
  Future<void> init() async {
    await repo.init();

    isFetching = false;

    load();
    emitterListen();
    broadcasterListen();
  }

  @override
  void emitterAction(String action) async {
    if (action == "cryptos_refresh_start") {
      debounceNotify();
    }

    if (action == repo.boxName) {
      load();
    }
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    if (event.op == 0x11) {
      if (event.boxName == "start") {
        isFetching = true;
        emitterEmit("cryptos_refresh_start");
      }

      if (event.boxName == "complete") {
        isFetching = false;
        emitterEmit(repo.boxName);
      }
    }

    if (event.op == 0x14 && event.boxName == repo.boxName) {
      emitterEmit(repo.boxName);
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
    await ipcClient.send(op: 0x11, box: "action");
    isFetching = false;
  }
}
