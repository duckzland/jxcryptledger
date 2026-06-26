import 'dart:async';
import 'package:flutter/material.dart';

import '../../app/runtime.dart';
import '../log.dart';
import '../mixins/emitter.dart';
import '../mixins/box.dart';
import 'models/with_id.dart';
import 'repository.dart';

abstract class CoreBaseController<T extends CoreModelWithId, R extends CoreBaseRepository<T>> extends ChangeNotifier
    with CoreMixinsBox<T>, CoreMixinsEmitter {
  Timer? _notifyTimer;

  List<T> listItems = [];
  List<T> get items => listItems;

  @override
  final R repo;

  CoreBaseController(this.repo);

  Future<void> init() async {
    await repo.init();
    load();
    emitterListen();
  }

  @override
  void emitterAction(String action) {
    if (action == repo.boxName) {
      load();
    }
  }

  void start() {
    listItems = repo.extract();
  }

  @override
  void load() {
    start();
    // logln("Scheduling listener for: ${T.toString()}");

    if (!AppRuntime.instance.isServer()) {
      _notifyTimer?.cancel();
      _notifyTimer = Timer(const Duration(milliseconds: 32), () {
        logln("[CORE] Firing listener for: ${T.toString()}");
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
    emitterDispose();
    _notifyTimer?.cancel();
    super.dispose();
  }
}
