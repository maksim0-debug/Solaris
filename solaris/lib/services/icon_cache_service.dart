import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// High-performance caching service for Windows application icons in Solaris.
///
/// Handles disk caching via MD5 hashes, in-flight request deduplication,
/// and delegates extraction to the native C++ Win32 layer.
class IconCacheService {
  static const MethodChannel _channel = MethodChannel(
    'com.solaris.monitor/icons',
  );
  static IconCacheService? _instance;
  static Future<IconCacheService>? _initFuture;

  /// Maximum simultaneous native icon extractions to prevent OS thread bombing and Win32 snapshot flooding.
  static const int maxConcurrentExtractions = 4;
  int _activeExtractions = 0;
  final List<Completer<void>> _extractionQueue = [];

  @visibleForTesting
  int get activeExtractions => _activeExtractions;

  @visibleForTesting
  int get queueLength => _extractionQueue.length;

  // In-flight deduplication cache to prevent duplicate Win32 calls and file lock races
  final Map<String, Future<String?>> _inFlightRequests = {};

  late Directory _cacheDir;
  bool _cacheDirCreated = false;

  IconCacheService._();

  static Future<IconCacheService> get instance async {
    if (_instance != null) {
      return _instance!;
    }
    _initFuture ??= _createInstance();
    return _initFuture!;
  }

  static Future<IconCacheService> _createInstance() async {
    final service = IconCacheService._();
    await service._init();
    _instance = service;
    _initFuture = null;
    return service;
  }

  @visibleForTesting
  static void resetInstance() {
    if (_instance != null) {
      for (final waiter in _instance!._extractionQueue) {
        if (!waiter.isCompleted) {
          waiter.complete();
        }
      }
      _instance!._extractionQueue.clear();
      _instance!._activeExtractions = 0;
      _instance!._inFlightRequests.clear();
    }
    _instance = null;
    _initFuture = null;
  }

  Future<void> _acquireExtractionSlot() {
    if (_activeExtractions < maxConcurrentExtractions) {
      _activeExtractions++;
      return Future.value();
    }
    final completer = Completer<void>();
    _extractionQueue.add(completer);
    return completer.future;
  }

  void _releaseExtractionSlot() {
    while (_extractionQueue.isNotEmpty) {
      final next = _extractionQueue.removeAt(0);
      if (!next.isCompleted) {
        next.complete();
        return;
      }
    }
    if (_activeExtractions > 0) {
      _activeExtractions--;
    }
  }

  Future<T> _withExtractionSlot<T>(Future<T> Function() action) async {
    await _acquireExtractionSlot();
    try {
      return await action();
    } finally {
      _releaseExtractionSlot();
    }
  }

  Future<void> _init() async {
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      _cacheDir = Directory(
        p.join(appSupportDir.path, 'Solaris', 'IconsCache'),
      );
      await _ensureCacheDir();
    } catch (_) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        _cacheDir = Directory(p.join(docDir.path, 'Solaris', 'IconsCache'));
        await _ensureCacheDir();
      } catch (_) {
        final tempDir = Directory.systemTemp;
        _cacheDir = Directory(p.join(tempDir.path, 'Solaris', 'IconsCache'));
        await _ensureCacheDir();
      }
    }
  }

  Future<void> _ensureCacheDir() async {
    if (!_cacheDirCreated || !await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
      _cacheDirCreated = true;
    }
  }

  /// Timeout for native icon extraction to prevent hung operations.
  static const Duration extractionTimeout = Duration(seconds: 4);

  /// Timeout for the entire getCachedIconPath operation (including queuing time).
  static const Duration requestTimeout = Duration(seconds: 15);

  /// Normalizes an executable or process name by trimming, adding `.exe` if missing extension, and lowercasing.
  String _normalizeName(String input) {
    String trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!trimmed.toLowerCase().endsWith('.exe')) {
      trimmed = '$trimmed.exe';
    }
    return trimmed.toLowerCase();
  }

  /// Hashes an executable name or explicit full path to create a safe lowercase filename.
  /// If [exePath] is provided, hashes the full path to avoid collision between executables
  /// that share common names (e.g. `launcher.exe`, `client.exe`).
  String _hashName(String input, {String? exePath}) {
    final String target;
    if (exePath != null && exePath.trim().isNotEmpty) {
      target = exePath.trim().toLowerCase();
    } else {
      target = _normalizeName(input);
    }
    final bytes = utf8.encode(target);
    final digest = md5.convert(bytes);
    return '${digest.toString()}.png';
  }

  /// Retrieves the cached icon path for a given application name.
  /// If [exePath] is provided and the icon isn't cached, it extracts it.
  Future<String?> getCachedIconPath(String name, {String? exePath}) async {
    final normName = _normalizeName(name);
    if (normName.isEmpty || normName == 'unknown.exe') return null;

    final dedupeKey = 'exe_${normName}_${exePath?.trim().toLowerCase() ?? ""}';
    if (_inFlightRequests.containsKey(dedupeKey)) {
      return _inFlightRequests[dedupeKey];
    }

    final future = _resolveIconPathInternal(normName, exePath: exePath).timeout(
      requestTimeout,
      onTimeout: () {
        debugPrint('Timed out resolving icon for $normName');
        return null;
      },
    );
    _inFlightRequests[dedupeKey] = future;
    try {
      return await future;
    } catch (e) {
      debugPrint('Error getting cached icon for $normName: $e');
      return null;
    } finally {
      final _ = _inFlightRequests.remove(dedupeKey);
    }
  }

  /// PNG header magic bytes (8 bytes: 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n').
  static const List<int> _pngMagicBytes = [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
  ];

  /// Validates that a cached icon file exists, has valid non-corrupt PNG size (>64 bytes),
  /// and begins with the valid PNG magic signature bytes.
  /// If the file is invalid, corrupt, or truncated, deletes it automatically.
  Future<bool> _isValidCacheFile(File file) async {
    if (!await file.exists()) return false;
    try {
      if (await file.length() > 64) {
        final raf = await file.open(mode: FileMode.read);
        try {
          final header = await raf.read(8);
          if (header.length == 8 &&
              header[0] == _pngMagicBytes[0] &&
              header[1] == _pngMagicBytes[1] &&
              header[2] == _pngMagicBytes[2] &&
              header[3] == _pngMagicBytes[3] &&
              header[4] == _pngMagicBytes[4] &&
              header[5] == _pngMagicBytes[5] &&
              header[6] == _pngMagicBytes[6] &&
              header[7] == _pngMagicBytes[7]) {
            return true;
          }
        } finally {
          await raf.close();
        }
      }
      await file.delete();
    } catch (_) {}
    return false;
  }

  Future<String?> _resolveIconPathInternal(
    String name, {
    String? exePath,
  }) async {
    try {
      await _ensureCacheDir();

      final customFileName = 'custom_${_hashName(name, exePath: exePath)}';
      final File customIconFile = File(p.join(_cacheDir.path, customFileName));
      if (await _isValidCacheFile(customIconFile)) {
        return customIconFile.path;
      }

      final fileName = _hashName(name, exePath: exePath);
      final File iconFile = File(p.join(_cacheDir.path, fileName));

      if (await _isValidCacheFile(iconFile)) {
        return iconFile.path;
      }

      // Backward compatibility: if exePath was provided, check legacy name-only cache
      if (exePath != null && exePath.trim().isNotEmpty) {
        final legacyFileName = _hashName(name);
        final File legacyIconFile = File(
          p.join(_cacheDir.path, legacyFileName),
        );
        if (await _isValidCacheFile(legacyIconFile)) {
          return legacyIconFile.path;
        }
      }

      final String lookupPath = (exePath == null || exePath.isEmpty)
          ? name
          : exePath;

      // Ask C++ Win32 layer to asynchronously extract and save the icon,
      // throttled via the concurrency limiter to prevent OS thread bombing.
      return await _withExtractionSlot(() async {
        // Re-check disk cache in case a previous extraction populated it while this was queued
        if (await _isValidCacheFile(iconFile)) {
          return iconFile.path;
        }

        try {
          final resolvedPath = await _channel
              .invokeMethod<String>('extractAppIcon', {
                'exePath': lookupPath,
                'savePath': iconFile.path,
              })
              .timeout(extractionTimeout, onTimeout: () => null);

          if (resolvedPath != null &&
              resolvedPath.isNotEmpty &&
              await _isValidCacheFile(iconFile)) {
            return iconFile.path;
          }
          // Check if file was populated concurrently
          if (await _isValidCacheFile(iconFile)) {
            return iconFile.path;
          }
        } catch (e) {
          debugPrint('Failed to extract app icon for $name: $e');
        }

        return null;
      });
    } catch (e) {
      debugPrint('Error resolving icon internal for $name: $e');
      return null;
    }
  }

  /// Sets a custom icon for the given application name by copying it to the cache directory.
  Future<String?> setCustomIcon(
    String name,
    String sourcePath, {
    String? exePath,
  }) async {
    await _ensureCacheDir();
    final customFileName = 'custom_${_hashName(name, exePath: exePath)}';
    final File customIconFile = File(p.join(_cacheDir.path, customFileName));
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(customIconFile.path);
      return customIconFile.path;
    }
    return null;
  }

  /// Removes the custom icon for the given application name.
  Future<void> removeCustomIcon(String name, {String? exePath}) async {
    final customFileName = 'custom_${_hashName(name, exePath: exePath)}';
    final File customIconFile = File(p.join(_cacheDir.path, customFileName));
    if (await customIconFile.exists()) {
      await customIconFile.delete();
    }
  }

  /// Removes both custom and standard cached icon for the given application name
  /// to force a complete re-scan/re-extraction.
  Future<void> forceResetIcon(String name, {String? exePath}) async {
    final customFileName = 'custom_${_hashName(name, exePath: exePath)}';
    final File customIconFile = File(p.join(_cacheDir.path, customFileName));
    if (await customIconFile.exists()) {
      await customIconFile.delete();
    }

    final fileName = _hashName(name, exePath: exePath);
    final File iconFile = File(p.join(_cacheDir.path, fileName));
    if (await iconFile.exists()) {
      await iconFile.delete();
    }

    // Also clean legacy name-only cache if exePath was supplied
    if (exePath != null && exePath.trim().isNotEmpty) {
      final legacyFileName = _hashName(name);
      final File legacyIconFile = File(p.join(_cacheDir.path, legacyFileName));
      if (await legacyIconFile.exists()) {
        await legacyIconFile.delete();
      }
    }
  }
}
