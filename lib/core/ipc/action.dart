enum CoreIpcAction {
  response(0x00),
  put(0x02),
  delete(0x03),
  clear(0x04),
  flush(0x05),
  extract(0x06),
  multiPut(0x7),
  replace(0x8),
  notification(0x9),
  unlock(0x10),
  addRateQueue(0x11),
  refreshTickers(0x12),
  refreshRates(0x13),
  refreshCryptos(0x14),
  databaseCreated(0x15),
  error(0xFF),
  unknown(-1);

  final int code;
  const CoreIpcAction(this.code);

  static CoreIpcAction fromCode(int code) {
    for (final action in CoreIpcAction.values) {
      if (action.code == code) return action;
    }
    return CoreIpcAction.unknown;
  }
}
