enum SystemUnlockStatus {
  error(0),
  success(1),
  firstTime(2);

  final int value;
  const SystemUnlockStatus(this.value);

  static SystemUnlockStatus fromValue(int value) {
    return SystemUnlockStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid CoreIpcUnlockStatus value: $value'),
    );
  }

  bool isUnlocked() => this == SystemUnlockStatus.success || this == SystemUnlockStatus.firstTime;
  bool isFirstRun() => this == SystemUnlockStatus.firstTime;
}
