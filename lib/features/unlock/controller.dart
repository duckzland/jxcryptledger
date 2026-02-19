import 'package:flutter/foundation.dart';
import '../../core/encryption_service.dart';
import '../../app/storage.dart';

class UnlockController extends ChangeNotifier {
  bool _unlocked = false;
  bool get unlocked => _unlocked;

  Future<bool> unlock(String password) async {
    try {
      // 1. Load key derived from password
      await EncryptionService.instance.loadPasswordKey(password);

      // 2. Open settings box (now encrypted with the derived key)
      final settingsBox = await AppStorage.instance.openBox<String>(
        'settings_box',
      );

      // 3. Check if vault is initialized
      final encryptedMarker = settingsBox.get('vault_initialized');

      if (encryptedMarker == null) {
        // FIRST RUN → accept password and create marker
        final encrypted = await EncryptionService.instance.encrypt(
          "initialized",
        );

        await settingsBox.put('vault_initialized', encrypted);

        _unlocked = true;
        return true;
      }

      // 4. Vault exists → validate password by decrypting marker
      try {
        final decrypted = await EncryptionService.instance.decrypt(
          encryptedMarker,
        );

        if (decrypted == "initialized") {
          _unlocked = true;
          return true;
        }

        return false;
      } catch (_) {
        // Wrong password
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}
