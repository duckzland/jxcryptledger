import 'package:flutter/foundation.dart';
import '../../core/ipc/event.dart';
import '../../core/mixins/broadcaster.dart';
import 'repository.dart';
import 'keys.dart';

class SettingsController extends ChangeNotifier with CoreMixinsBroadcaster {
  final SettingsRepository repo;

  SettingsController(this.repo);

  Future<void> init() async {
    await repo.init();
    broadcasterListen();
  }

  @override
  void dispose() {
    broadcasterDispose();
    super.dispose();
  }

  @override
  void broadcasterAction(CoreIpcBroadcastEvent event) {
    if (event.action != repo.boxName) {
      return;
    }

    repo.receive(event);
    load();
  }

  T get<T>(SettingKey key, {T? defaultValue}) {
    return repo.get<T>(key, defaultValue: defaultValue) as T;
  }

  void load() {
    notifyListeners();
  }

  Future<void> update(SettingKey key, dynamic value) async {
    await repo.save(key, value);
    load();
  }

  Future<String?> getDecryptedMarker() async {
    return await repo.getDecryptedMarker();
  }
}
