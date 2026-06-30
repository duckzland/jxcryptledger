import 'package:flutter/foundation.dart';

import '../../../core/runtime/bootstrap/client.dart';
import '../../../core/runtime/locator.dart';
import '../../../core/log.dart';

class SystemUnlockController extends ChangeNotifier {
  bool _unlocked = false;
  bool get unlocked => _unlocked;
  bool get isFirstRun => client.isFirstRun;

  late CoreBootstrapClient client;

  Future<void> init() async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }

    client = locator<CoreBootstrapClient>();
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    try {
      _unlocked = await client.unlock(password);
      _unlocked = true;
      notifyListeners();

      return true;
    } catch (e) {
      logln("$e");
      return false;
    }
  }
}
