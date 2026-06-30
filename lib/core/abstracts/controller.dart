import 'dart:async';
import 'package:flutter/material.dart';

import '../ipc/event.dart';
import '../mixins/broadcaster.dart';
import '../runtime/runtime.dart';
import '../mixins/box.dart';
import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreModelWithId, R extends CoreBaseRepository<T>> extends ChangeNotifier
    with CoreMixinsBox<T>, CoreMixinsBroadcaster {
  Timer? _notifyTimer;

  List<T> listItems = [];
  List<T> get items => listItems;

  @override
  final R repo;

  CoreBaseController(this.repo);

  Future<void> init() async {
    await repo.init();
    load();
    broadcasterListen();
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    if (event.boxName != repo.boxName) {
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
    if (!CoreRuntime.instance.isServer()) {
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
