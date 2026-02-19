import 'package:flutter/foundation.dart';
import 'model.dart';
import 'repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository repo;

  SettingsModel? _settings;
  SettingsModel? get settings => _settings;

  SettingsController(this.repo);

  Future<void> load() async {
    _settings = await repo.load();
    notifyListeners();
  }

  Future<void> save(SettingsModel settings) async {
    await repo.save(settings);
    _settings = settings;
    notifyListeners();
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      await load();
      return;
    }

    _settings = await repo.filter(query);
    notifyListeners();
  }
}
