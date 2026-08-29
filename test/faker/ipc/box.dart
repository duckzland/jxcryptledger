import 'package:jxledger/ipc/abstracts/box.dart';
import 'package:jxledger/ipc/abstracts/model.dart';

class IpcBoxFaker<T extends IpcModel> extends IpcBox<T> {
  IpcBoxFaker(super.boxName, super.adapters, super.client);
}
