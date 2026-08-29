enum IpcStatusUnlock {
  error(0),
  success(1),
  firstTime(2);

  final int value;
  const IpcStatusUnlock(this.value);

  static IpcStatusUnlock fromValue(int value) {
    return IpcStatusUnlock.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Invalid CoreIpcStatus value: $value'),
    );
  }

  bool isUnlocked() => this == IpcStatusUnlock.success || this == IpcStatusUnlock.firstTime;
  bool isFirstRun() => this == IpcStatusUnlock.firstTime;
}
