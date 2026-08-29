import '../../../ipc/abstracts/box.dart';
import '../../abstracts/models/with_id.dart';
import '../../log.dart';

class CoreRuntimeIpcBox<T extends CoreModelWithId> extends IpcBox<T> {
  CoreRuntimeIpcBox(super.boxName, super.adapters, super.client);

  @override
  Future<void> init() async {
    await super.init();
    logln("Initialized standard box: $boxName|${items.length}", "IPC");
  }
}
