import 'dart:ffi';
import 'dart:io';

/// Native platform implementation for dynamic library loading via dart:ffi.
class NativeLibraryLoader {
  /// Dynamically loads matrix_sdk_ffi native library for host platform.
  static Object? loadNativeLibrary() {
    if (Platform.isAndroid) {
      return DynamicLibrary.open('libmatrix_sdk_ffi.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      return DynamicLibrary.process();
    } else if (Platform.isLinux) {
      return DynamicLibrary.open('libmatrix_sdk_ffi.so');
    } else if (Platform.isWindows) {
      return DynamicLibrary.open('matrix_sdk_ffi.dll');
    }
    return null;
  }

  /// Indicates if native FFI is supported on host platform.
  static bool isNativeAvailable() {
    return true;
  }
}
