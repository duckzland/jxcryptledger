import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:jxcryptledger/features/transactions/model.dart';
import '../../core/encryption_service.dart';
import '../../app/storage.dart';
import '../settings/repository.dart'; // Import your repository and enum

class UnlockController extends ChangeNotifier {
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  // Use the repository for setting operations
  final _settingsRepo = SettingsRepository();

  Future<bool> unlock(String password) async {
    // DEBUG: Simulating fresh install
    // await Hive.deleteBoxFromDisk('settings_box');
    // await Hive.deleteBoxFromDisk('transactions_box');

    try {
      // 1. Check if DB exists
      final bool isFirstRun = !(await AppStorage.instance.exists());

      // 2. Derive key
      final Uint8List encryptionKey = await EncryptionService.instance
          .loadPasswordKey(password);
      final cipher = HiveAesCipher(encryptionKey);

      // 3. Open boxes
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
        // Wrong password: Hive cannot decrypt existing files
        return false;
      }

      if (isFirstRun) {
        // 4. SETUP: Use Repo to save marker (it handles the encryption internally)
        await _settingsRepo.save(SettingKey.vaultInitialized, "initialized");

        // Add defaults using the type-safe enum
        await _settingsRepo.save(SettingKey.themeMode, 'system');
        await _settingsRepo.save(SettingKey.currency, 'USD');

        _unlocked = true;
        notifyListeners();
        return true;
      } else {
        // 5. VERIFY: Use Repo's specialized decryption method
        final decrypted = await _settingsRepo.getDecryptedMarker();

        if (decrypted == "initialized") {
          _unlocked = true;
          notifyListeners();
          return true;
        } else {
          // Wrong password - Decryption failed or marker missing
          await AppStorage.instance.closeAll();
          return false;
        }
      }
    } catch (_) {
      return false;
    }
  }
}
