import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../features/rates/controller.dart';
import '../../features/rates/model.dart';
import '../../features/transactions/model.dart';

import '../../app/storage.dart';
import '../../app/worker.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../cryptos/model.dart';
import '../encryption/service.dart';
import '../notification/service.dart';
import '../settings/controller.dart';
import '../settings/keys.dart';
import '../watchers/controller.dart';
import '../watchers/model.dart';

class UnlockController extends ChangeNotifier {
  bool isFirstRun = false;
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  final SettingsController _settingsController = locator<SettingsController>();
  final RatesController _ratesController = locator<RatesController>();
  final WatchersController _watchersController = locator<WatchersController>();
  final NotificationService _notificationService = locator<NotificationService>();
  final AppWorker _appWorker = locator<AppWorker>();

  Future<void> init() async {
    isFirstRun = !(await AppStorage.instance.exists());
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    try {
      final Uint8List encryptionKey = await EncryptionService.instance.loadPasswordKey(password);
      final cipher = HiveAesCipher(encryptionKey);

      await AppStorage.instance.openBox<dynamic>('settings_box', encryptionCipher: cipher, crashRecovery: false);

      await AppStorage.instance.openBox<TransactionsModel>('transactions_box', encryptionCipher: cipher, crashRecovery: false);
    } catch (e) {
      logln("Failed to decrypt boxes (wrong password)");
      return false;
    }

    try {
      await AppStorage.instance.openBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open cryptos box: ${e.toString()}");
      return false;
    }

    try {
      await AppStorage.instance.openBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open rates box: ${e.toString()}");
      return false;
    }

    try {
      await AppStorage.instance.openBox<WatchersModel>('watchers_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open watchers box: ${e.toString()}");
      return false;
    }

    try {
      if (isFirstRun) {
        logln("First run detected, initializing vault");

        await _settingsController.update(SettingKey.vaultInitialized, "initialized");

        _unlocked = true;
        notifyListeners();
        _appWorker.start();

        return true;
      }
    } catch (e) {
      logln("Failed to initialize vault");
      return false;
    }

    try {
      final decrypted = await _settingsController.getDecryptedMarker();

      if (decrypted != 'initialized') {
        await AppStorage.instance.closeAll();
        throw Exception("Failed to unlock vault due to marker mismatch");
      }

      logln("Password correct, vault unlocked");
      await Future.delayed(Duration.zero, () {
        _notificationService.init();
        _ratesController.init();
        _watchersController.init();
      });
      _unlocked = true;
      notifyListeners();
      _appWorker.start();

      return true;
    } catch (e) {
      logln("Failed to unlock vault due to marker mismatch");
      return false;
    }
  }
}
