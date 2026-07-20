import '../../ipc/database/migration.dart';

class CoreRuntimeMigration extends IpcMigration {
  @override
  Future<void> migrateBeforeUnlock() async {
    // Nothing to migrate after v1.1.0
  }

  @override
  Future<void> migrateAfterUnlock() async {
    // Nothing to migrate after v1.1.0
  }
}
