import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Saves a string to a file using atomic write (write to temp, then rename).
  Future<void> save(String filename, String data) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$filename');
      final tempFile = File('${directory.path}/$filename.tmp');
      final backupFile = File('${directory.path}/$filename.bak');

      // 1. Write to temporary file
      await tempFile.writeAsString(data, flush: true);

      // 2. If original exists, create a backup
      if (await file.exists()) {
        if (await backupFile.exists()) await backupFile.delete();
        await file.copy(backupFile.path);
      }

      // 3. Rename temp to original (Atomic on most filesystems)
      // On Windows, rename often fails if the destination is recently read.
      int retries = 0;
      bool success = false;
      while (retries < 3 && !success) {
        try {
          await tempFile.rename(file.path);
          success = true;
        } catch (e) {
          retries++;
          if (retries < 3) {
            await Future<void>.delayed(Duration(milliseconds: 100 * retries));
          } else {
            // Final fallback: Try direct write if rename is permanently blocked
            debugPrint('Rename failed after retries, falling back to direct write: $e');
            await file.writeAsString(data, flush: true);
            if (await tempFile.exists()) await tempFile.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Error saving $filename: $e');
    }
  }

  /// Loads a string from a file, falling back to backup if corrupted.
  Future<String?> load(String filename) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$filename');
      final backupFile = File('${directory.path}/$filename.bak');

      if (await file.exists()) {
        try {
          final data = await file.readAsString();
          // Optional: validate JSON if expected
          if (filename.endsWith('.json')) jsonDecode(data);
          return data;
        } catch (e) {
          debugPrint('Error loading $filename, trying backup: $e');
          if (await backupFile.exists()) {
            return await backupFile.readAsString();
          }
        }
      } else if (await backupFile.exists()) {
        return await backupFile.readAsString();
      }
    } catch (e) {
      debugPrint('Error in load $filename: $e');
    }
    return null;
  }

  /// Deletes the main file and backup for the given filename.
  Future<void> clear(String filename) async {
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/$filename');
      final backupFile = File('${directory.path}/$filename.bak');

      if (await file.exists()) await file.delete();
      if (await backupFile.exists()) await backupFile.delete();
    } catch (e) {
      debugPrint('Error clearing $filename: $e');
    }
  }
}
