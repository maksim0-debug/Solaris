import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class AutorunService {
  static const String _keyName = 'Solaris';
  static const String _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';

  /// Enables or disables autorun for the current application on Windows.
  static Future<bool> setEnabled(bool enabled) async {
    if (!Platform.isWindows) return false;

    final phkResult = calloc<HKEY>();
    try {
      final subKeyPtr = _runKeyPath.toNativeUtf16();
      final status = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        subKeyPtr,
        0,
        KEY_SET_VALUE,
        phkResult,
      );
      free(subKeyPtr);

      if (status != ERROR_SUCCESS) {
        print('Failed to open registry key: $status');
        return false;
      }

      final hKey = phkResult.value;
      final valueNamePtr = _keyName.toNativeUtf16();

      if (enabled) {
        final executablePath = '${Platform.resolvedExecutable} --minimized';
        final dataPtr = executablePath.toNativeUtf16();
        final dataSize = (executablePath.length + 1) * 2;
        
        final setStatus = RegSetValueEx(
          hKey,
          valueNamePtr,
          0,
          REG_SZ,
          dataPtr.cast<Uint8>(),
          dataSize,
        );
        free(dataPtr);
        
        if (setStatus != ERROR_SUCCESS) {
          print('Failed to set registry value: $setStatus');
          RegCloseKey(hKey);
          free(valueNamePtr);
          return false;
        }
      } else {
        final deleteStatus = RegDeleteValue(hKey, valueNamePtr);
        if (deleteStatus != ERROR_SUCCESS && deleteStatus != ERROR_FILE_NOT_FOUND) {
          print('Failed to delete registry value: $deleteStatus');
          RegCloseKey(hKey);
          free(valueNamePtr);
          return false;
        }
      }

      RegCloseKey(hKey);
      free(valueNamePtr);
      return true;
    } finally {
      free(phkResult);
    }
  }

  /// Checks if the autorun registry key exists and matches the current executable.
  static Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;

    final phkResult = calloc<HKEY>();
    try {
      final subKeyPtr = _runKeyPath.toNativeUtf16();
      final status = RegOpenKeyEx(
        HKEY_CURRENT_USER,
        subKeyPtr,
        0,
        KEY_QUERY_VALUE,
        phkResult,
      );
      free(subKeyPtr);

      if (status != ERROR_SUCCESS) return false;

      final hKey = phkResult.value;
      final valueNamePtr = _keyName.toNativeUtf16();
      
      final lpcbData = calloc<DWORD>();
      // First call to get the required buffer size
      var queryStatus = RegQueryValueEx(
        hKey,
        valueNamePtr,
        nullptr,
        nullptr,
        nullptr,
        lpcbData,
      );

      bool exists = false;
      if (queryStatus == ERROR_SUCCESS) {
        final lpData = calloc<BYTE>(lpcbData.value);
        queryStatus = RegQueryValueEx(
          hKey,
          valueNamePtr,
          nullptr,
          nullptr,
          lpData,
          lpcbData,
        );
        
        if (queryStatus == ERROR_SUCCESS) {
          final registeredPath = lpData.cast<Utf16>().toDartString();
          exists = registeredPath.contains(Platform.resolvedExecutable);
        }
        free(lpData);
      }

      RegCloseKey(hKey);
      free(valueNamePtr);
      free(lpcbData);
      return exists;
    } finally {
      free(phkResult);
    }
  }
}
