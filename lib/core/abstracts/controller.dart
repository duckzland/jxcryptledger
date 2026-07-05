import 'dart:async';
import 'package:flutter/material.dart';

import '../../ipc/client.dart';
import '../../ipc/event.dart';
import '../../ipc/mixins/broadcaster.dart';
import '../../ipc/server.dart';
import '../mode.dart';
import '../mixins/box.dart';
import '../runtime/locator.dart';
import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreModelWithId, R extends CoreBaseRepository<T>> extends ChangeNotifier
    with CoreMixinsBox<T>, IpcMixinsBroadcaster {
  Timer? _notifyTimer;

  List<T> listItems = [];
  List<T> get items => listItems;

  @override
  IpcClient get ipcClient => locator<IpcClient>();

  @override
  IpcServer get ipcServer => locator<IpcServer>();

  @override
  final R repo;

  CoreBaseController(this.repo);

  Future<void> init() async {
    await repo.init();
    load();
    broadcasterListen();
  }

  @override
  void broadcasterAction(IpcBroadcastEvent event) {
    if (event.action != repo.boxName) {
      return;
    }

    repo.receive(event);
    load();
  }

  void start() {
    listItems = repo.extract();
  }

  @override
  void load() {
    start();
    debounceNotify();
  }

  void debounceNotify() {
    if (!CoreMode.isServer) {
      _notifyTimer?.cancel();
      _notifyTimer = Timer(const Duration(milliseconds: 32), () {
        notifyListeners();
      });
    }
  }

  T? findNew(List<T> oldItems) {
    final oldIds = oldItems.map((t) => t.uuid).toSet();
    final addedIds = items.map((t) => t.uuid).where((id) => !oldIds.contains(id));

    if (addedIds.isEmpty) {
      return null;
    }

    return items.firstWhere((el) => el.uuid == addedIds.first);
  }

  @override
  void dispose() {
    broadcasterDispose();
    _notifyTimer?.cancel();
    super.dispose();
  }
}
