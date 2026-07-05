class IpcMigration {
  Future<void> migrateBeforeUnlock() async {}

  Future<void> migrateAfterUnlock() async {}

  bool isVersionLessThan(String current, String target) {
    final currentParts = current.split('.').map(int.parse).toList();
    final targetParts = target.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (currentParts[i] < targetParts[i]) return true;
      if (currentParts[i] > targetParts[i]) return false;
    }
    return false;
  }
}
