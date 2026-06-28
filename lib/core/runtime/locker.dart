import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import '../log.dart';

typedef NativeAcquire = Pointer<Void> Function(Pointer<Utf8> filePath);
typedef DartAcquire = Pointer<Void> Function(Pointer<Utf8> filePath);

typedef NativeRelease = Void Function(Pointer<Void> handle);
typedef DartRelease = void Function(Pointer<Void> handle);

final DynamicLibrary _nativeLib = DynamicLibrary.executable();

final DartAcquire nativeAcquireLock = _nativeLib.lookup<NativeFunction<NativeAcquire>>('acquire_kernel_lock').asFunction();

final DartRelease nativeReleaseLock = _nativeLib.lookup<NativeFunction<NativeRelease>>('release_kernel_lock').asFunction();

class CoreLocker {
  static Pointer<Void>? _activeServerHandle;

  static void lockAndCleanHive(String hivePath) {
    if (_activeServerHandle != null) return;

    try {
      final lockMarkerPath = '$hivePath/kernel_lock.marker';
      final Pointer<Utf8> pathPtr = lockMarkerPath.toNativeUtf8();

      final Pointer<Void> token = nativeAcquireLock(pathPtr);
      calloc.free(pathPtr);

      if (token == nullptr) {
        exit(0);
      }

      _activeServerHandle = token;

      final dir = Directory(hivePath);
      if (dir.existsSync()) {
        for (final file in dir.listSync()) {
          final String filename = file.path.toLowerCase();

          if (file is File && filename.endsWith('.lock')) {
            try {
              file.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      logln("[LOCK] Error during server session lock and cleanup: $e");
    }
  }

  static void release() {
    if (_activeServerHandle != null && _activeServerHandle != nullptr) {
      nativeReleaseLock(_activeServerHandle!);
      _activeServerHandle = null;
      logln("[LOCK] Server runtime lock released cleanly.");
    }
  }
}
