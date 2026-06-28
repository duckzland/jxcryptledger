import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _NativeGetPids = Int32 Function(Pointer<Int32> outPids, Int32 maxCount);
typedef _DartGetPids = int Function(Pointer<Int32> outPids, int maxCount);

typedef _NativeIsServerRunning = Int32 Function();
typedef _DartIsServerRunning = int Function();

class CoreProcessDetector {
  CoreProcessDetector._();

  static final DynamicLibrary _processLib = DynamicLibrary.executable();

  static final _DartGetPids _nativeGetPids = _processLib.lookup<NativeFunction<_NativeGetPids>>('get_active_process_pids').asFunction();

  static final _DartIsServerRunning _nativeIsServerRunning = _processLib
      .lookup<NativeFunction<_NativeIsServerRunning>>('is_server_instance_running')
      .asFunction();

  static List<int> getActiveUiClientPids() {
    // FIX: Support both platform binaries
    if (!Platform.isWindows && !Platform.isLinux) return [];

    final Pointer<Int32> pidsArrayPtr = calloc<Int32>(128);
    final List<int> uiClientPids = [];

    try {
      final int count = _nativeGetPids(pidsArrayPtr, 128);
      for (int i = 0; i < count; i++) {
        uiClientPids.add(pidsArrayPtr[i]);
      }
    } finally {
      calloc.free(pidsArrayPtr);
    }
    return uiClientPids;
  }

  static bool isServerInstanceRunning() {
    // FIX: Support both platform binaries
    if (!Platform.isWindows && !Platform.isLinux) return false;
    return _nativeIsServerRunning() == 1;
  }
}
