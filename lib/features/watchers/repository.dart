import 'dart:math';

import 'package:hive_ce/hive_ce.dart';
import '../../core/locator.dart';
import '../../core/utils.dart';
import '../notification/service.dart';
import '../rates/controller.dart';
import 'model.dart';

class WatchersRepository {
  static const boxName = 'watchers_box';

  Box<WatchersModel> get _box => Hive.box<WatchersModel>(boxName);
  RatesController get rates => locator<RatesController>();

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<WatchersModel>(boxName);
    }
  }

  String generateWid() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();

    while (true) {
      final now = DateTime.now().microsecondsSinceEpoch;
      final timePart = now.toRadixString(36).padLeft(4, '0');
      final timeSuffix = timePart.substring(timePart.length - 4);
      final randomPart = String.fromCharCodes(Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))));

      final id = '$timeSuffix$randomPart';
      if (!_box.containsKey(id)) {
        return id;
      }
    }
  }

  Future<List<WatchersModel>> getAll() async {
    final list = <WatchersModel>[];
    for (final key in _box.keys) {
      final tx = _box.get(key);
      if (tx != null) list.add(tx);
    }
    return list;
  }

  Future<void> saveAll(List<WatchersModel> watchers) async {
    await _box.clear();
    for (final w in watchers) {
      await _box.put(w.wid, w);
    }
  }

  Future<void> add(WatchersModel watcher) async {
    return await _box.put(watcher.wid, watcher);
  }

  Future<void> update(WatchersModel watcher) async {
    await _box.put(watcher.wid, watcher);
  }

  Future<void> delete(String key) async {
    await _box.delete(key);
  }

  Future<int> clear() async {
    return await _box.clear();
  }

  bool isEmpty() {
    return _box.isEmpty;
  }

  Future<void> evaluateWatcher(WatchersModel w) async {
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;

    final last = Utils.sanitizeTimestamp(w.timestamp);

    if (w.limit > 0 && w.sent >= w.limit) return;

    final nextAllowed = last + (w.duration * 60000000);
    if (now < nextAllowed) return;

    final current = await rates.getStoredRate(w.srId, w.rrId);
    if (current == -9999) {
      rates.addQueue(w.srId, w.rrId);
      return;
    }
    
    if (current < w.rates) return;

    final updated = w.copyWith(sent: w.sent + 1, timestamp: now);

    await _box.put(w.wid, updated);

    final notify = locator<NotificationService>();
    await notify.show(w.message);
  }
}
