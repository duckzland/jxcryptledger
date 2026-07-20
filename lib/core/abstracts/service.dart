import '../../ipc/mixins/broadcaster.dart';
import '../../ipc/client.dart';
import '../../ipc/event.dart';
import '../../ipc/server.dart';
import '../runtime/locator.dart';
import '../mode.dart';
import '../mixins/box.dart';
import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseService<T extends CoreModelWithId, R extends CoreBaseRepository<T>> with CoreMixinsBox<T>, IpcMixinsBroadcaster {
  @override
  final R repo;

  CoreBaseService(this.repo);

  @override
  bool get isBroadcastable => CoreMode.isServer;

  @override
  IpcClient get ipcClient => locator<IpcClient>();

  @override
  IpcServer get ipcServer => locator<IpcServer>();

  Future<void> init() async {
    repo.init();
    broadcasterListen();
  }

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    if (event.action != repo.boxName) {
      return;
    }

    repo.receive(event);
  }

  Future<void> dispose() async {
    broadcasterDispose();
  }

  T? findNew(List<T> oldItems) {
    final items = repo.extract();
    final oldIds = oldItems.map((t) => t.uuid).toSet();
    final addedIds = items.map((t) => t.uuid).where((id) => !oldIds.contains(id));

    if (addedIds.isEmpty) {
      return null;
    }

    return items.firstWhere((el) => el.uuid == addedIds.first);
  }
}
