import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/transactions/model.dart';

import '../../app/storage.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../cryptos/model.dart';
import '../cryptos/service.dart';
import '../encryption/service.dart';
import '../rates/service.dart';
import '../settings/repository.dart';

class UnlockController extends ChangeNotifier {
  bool isFirstRun = false;
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  final _settingsRepo = SettingsRepository();
  final CryptosService _cryptosService = locator<CryptosService>();
  final RatesService _ratesService = locator<RatesService>();

  Future<void> init() async {
    isFirstRun = !(await AppStorage.instance.exists());
    notifyListeners();
  }

  Future<bool> unlock(String password) async {
    try {
      final Uint8List encryptionKey = await EncryptionService.instance.loadPasswordKey(password);
      final cipher = HiveAesCipher(encryptionKey);

      try {
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

      await AppStorage.instance.openBox<CryptosModel>('cryptos_box', encryptionCipher: null, crashRecovery: true);

      await AppStorage.instance.openBox<RatesModel>('rates_box', encryptionCipher: null, crashRecovery: true);

      if (isFirstRun) {
        logln("First run detected, initializing vault");

        await _settingsRepo.save(SettingKey.vaultInitialized, "initialized");

        _unlocked = true;
        notifyListeners();

        return true;
      }

      final decrypted = await _settingsRepo.getDecryptedMarker();

      if (decrypted == "initialized") {
        logln("Password correct, vault unlocked");
        await _ratesService.init();
        _unlocked = true;
        notifyListeners();
        return true;
      }

      logln("Marker mismatch, wrong password");
      await AppStorage.instance.closeAll();
      return false;
    } catch (e, st) {
      logln("Unexpected error: $e");
      logln("$st");
      return false;
    }
  }
}
