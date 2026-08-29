class IpcStatusOp {
  static final Map<int, String> _codeToName = {};
  static final Map<String, int> _nameToCode = {};

  static void register(int code, String name) {
    _codeToName[code] = name;
    _nameToCode[name] = code;
  }

  static String getName(int code) => _codeToName[code] ?? "unknown";

  static int getCode(String name) => _nameToCode[name] ?? -1;
}
