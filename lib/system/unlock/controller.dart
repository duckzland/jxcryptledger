import 'package:flutter/foundation.dart';
import 'package:jxledger/core/runtime/client.dart';

import '../../core/mode.dart';
import '../../core/runtime/locator.dart';
import '../../core/log.dart';

class SystemUnlockController extends ChangeNotifier {
  bool _unlocked = false;
  bool get unlocked => _unlocked;
  bool get isFirstRun => CoreMode.isFirstRun;

  late CoreRuntimeClient client;

  Future<void> init() async {
    if (kIsWeb) {
      notifyListeners();
      return;
    }

    client = locator<CoreRuntimeClient>();
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    try {
      _unlocked = await client.unlock(password);
      notifyListeners();

      return true;
    } catch (e) {
      logln("$e");
      return false;
    }
  }
}
