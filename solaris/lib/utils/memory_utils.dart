import 'dart:ffi';
import 'dart:io';
import 'package:flutter/widgets.dart';

typedef _SetProcessWorkingSetSizeC = Int32 Function(
  IntPtr hProcess,
  IntPtr dwMinimumWorkingSetSize,
  IntPtr dwMaximumWorkingSetSize,
);

typedef _SetProcessWorkingSetSizeDart = int Function(
  int hProcess,
  int dwMinimumWorkingSetSize,
  int dwMaximumWorkingSetSize,
);

/// Utility for forced memory eviction and OS working set trimming.
class MemoryUtils {
  static _SetProcessWorkingSetSizeDart? _win32TrimFunction;
  static bool _win32LookupAttempted = false;

  /// Evicts Flutter image cache and triggers Windows Win32 working set trim,
  /// causing Windows Task Manager to instantly reclaim unused heap memory (~60-80 MB).
  static void trimMemory() {
    // 1. Evict decoded bitmaps from Flutter ImageCache
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('MemoryUtils: imageCache clear failed: $e');
    }

    // 2. Win32 Working Set Trim (Windows desktop optimization)
    if (Platform.isWindows) {
      _trimWin32WorkingSet();
    }
  }

  static void _trimWin32WorkingSet() {
    try {
      if (!_win32LookupAttempted) {
        _win32LookupAttempted = true;
        final kernel32 = DynamicLibrary.open('kernel32.dll');
        _win32TrimFunction = kernel32.lookupFunction<
            _SetProcessWorkingSetSizeC,
            _SetProcessWorkingSetSizeDart>('SetProcessWorkingSetSize');
      }

      // Pseudo handle -1 refers to GetCurrentProcess()
      // Passing -1, -1 forces Windows to flush all unreferenced physical pages back to OS
      _win32TrimFunction?.call(-1, -1, -1);
    } catch (e) {
      debugPrint('MemoryUtils: Win32 SetProcessWorkingSetSize failed: $e');
    }
  }
}
