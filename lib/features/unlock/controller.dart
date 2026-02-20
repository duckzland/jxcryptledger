import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/rates/model.dart';
import 'package:jxcryptledger/features/transactions/model.dart';

import '../../core/encryption_service.dart';
import '../../core/locator.dart';
import '../../core/log.dart';
import '../../app/storage.dart';

import '../settings/repository.dart';

import '../cryptos/model.dart';
import '../cryptos/service.dart';

class UnlockController extends ChangeNotifier {
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  final _settingsRepo = SettingsRepository();
  final CryptosService _cryptosService = locator<CryptosService>();

  Future<bool> unlock(String password) async {
    try {
      final bool isFirstRun = !(await AppStorage.instance.exists());
      final Uint8List encryptionKey = await EncryptionService.instance
          .loadPasswordKey(password);
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
        Logln("Failed to decrypt boxes (wrong password)");
        return false;
      }

      await AppStorage.instance.openBox<CryptosModel>(
        'cryptos_box',
        encryptionCipher: null,
        crashRecovery: true,
      );

      await AppStorage.instance.openBox<RatesModel>(
        'rates_box',
        encryptionCipher: null,
        crashRecovery: true,
      );

      if (isFirstRun) {
        Logln("First run detected, initializing vault");

        await _settingsRepo.save(SettingKey.vaultInitialized, "initialized");

        _unlocked = true;
        notifyListeners();

        Future.microtask(() async {
          final ok = await _cryptosService.fetch();
          if (!ok) Logln("Failed to fetch cryptos on first run");
        });

        return true;
      }

      final decrypted = await _settingsRepo.getDecryptedMarker();

      if (decrypted == "initialized") {
        Logln("Password correct, vault unlocked");
        _unlocked = true;
        notifyListeners();
        return true;
      }

      Logln("Marker mismatch, wrong password");
      await AppStorage.instance.closeAll();
      return false;
    } catch (e, st) {
      Logln("Unexpected error: $e");
      Logln("$st");
      return false;
    }
  }
}
