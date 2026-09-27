/// Web / Non-FFI fallback implementation for native library loading.
class NativeLibraryLoader {
  /// Always returns null on Web / Non-FFI platforms.
  static Object? loadNativeLibrary() {
    return null;
  }

  /// Returns false on Web / Non-FFI platforms.
  static bool isNativeAvailable() {
    return false;
  }
}
