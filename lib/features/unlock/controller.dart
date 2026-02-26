import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/transactions/model.dart';

import '../../app/storage.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../cryptos/model.dart';
import '../encryption/service.dart';
import '../rates/service.dart';
import '../settings/repository.dart';

class UnlockController extends ChangeNotifier {
  bool isFirstRun = false;
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  final SettingsRepository _settingsRepo = locator<SettingsRepository>();
  final RatesService _ratesService = locator<RatesService>();

  Future<void> init() async {
    isFirstRun = !(await AppStorage.instance.exists());
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    try {
      final Uint8List encryptionKey = await EncryptionService.instance.loadPasswordKey(password);
      final cipher = HiveAesCipher(encryptionKey);

      await AppStorage.instance.openBox<dynamic>(
        SettingsRepository.boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );

      await AppStorage.instance.openBox<TransactionsModel>(
        'transactions_box',
        encryptionCipher: cipher,
        crashRecovery: false,
      );
    } catch (e) {
      logln("Failed to decrypt boxes (wrong password)");
      return false;
    }

    try {
      await AppStorage.instance.openBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open cryptos box");
      return false;
    }

    try {
      await AppStorage.instance.openBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: false);
    } catch (e) {
      logln("Failed to open rates box");
      return false;
    }

    try {
      if (isFirstRun) {
        logln("First run detected, initializing vault");

        await _settingsRepo.save(SettingKey.vaultInitialized, "initialized");

        _unlocked = true;
        notifyListeners();

        return true;
      }
    } catch (e) {
      logln("Failed to initialize vault");
      return false;
    }

    try {
      final decrypted = await _settingsRepo.getDecryptedMarker();

      if (decrypted != 'initialized') {
        await AppStorage.instance.closeAll();
        throw Exception("Failed to unlock vault due to marker mismatch");
      }

      logln("Password correct, vault unlocked");
      await Future.delayed(Duration.zero, () => _ratesService.init());
      _unlocked = true;
      notifyListeners();

      return true;
    } catch (e) {
      logln("Failed to unlock vault due to marker mismatch");
      return false;
    }
  }
}
