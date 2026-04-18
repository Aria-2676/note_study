import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

mixin DatabaseBackupMixin {
  static const String _backupPathKey = 'backup_storage_path';
  Future<Database> get database;
  String get dbName;

  Future<String> backupDatabase({
    String? customPath,
    String? backupName,
  }) async {
    final dbPath = await getDatabasesPath();
    final sourcePath = join(dbPath, dbName);
    final sourceFile = File(sourcePath);

    if (!await sourceFile.exists()) {
      throw Exception('数据库文件不存在');
    }

    final backupDir = await _getBackupDirectory(customPath);
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:-]'),
      '_',
    );

    String fileName;
    if (backupName != null && backupName.trim().isNotEmpty) {
      final safeName = backupName.trim().replaceAll(
        RegExp(r'[^\w\u4e00-\u9fa5]'),
        '_',
      );
      fileName = 'noteapp_backup_${safeName}_$timestamp.db';
    } else {
      fileName = 'noteapp_backup_$timestamp.db';
    }
    final destPath = join(backupDir.path, fileName);

    await sourceFile.copy(destPath);
    return destPath;
  }

  Future<bool> importDatabase(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        return false;
      }

      await _closeDatabase();

      final dbPath = await getDatabasesPath();
      final destPath = join(dbPath, dbName);

      await backupFile.copy(destPath);

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getBackupFiles({String? customPath}) async {
    try {
      final backupDir = await _getBackupDirectory(customPath);
      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().where((entity) {
        return entity is File &&
            entity.path.endsWith('.db') &&
            entity.path.contains('noteapp_backup');
      }).toList();

      files.sort((a, b) => b.path.compareTo(a.path));
      return files.map((f) => f.path).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllBackupFiles() async {
    final allBackups = <Map<String, dynamic>>[];

    final downloadsBackups = await _getBackupsFromLocation('downloads', '下载目录');
    allBackups.addAll(downloadsBackups);

    final defaultBackups = await _getBackupsFromLocation(null, '应用私有目录');
    allBackups.addAll(defaultBackups);

    allBackups.sort((a, b) {
      final timeA = a['timestamp'] as DateTime?;
      final timeB = b['timestamp'] as DateTime?;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeB.compareTo(timeA);
    });

    return allBackups;
  }

  Future<List<Map<String, dynamic>>> _getBackupsFromLocation(
    String? location,
    String locationName,
  ) async {
    final backups = <Map<String, dynamic>>[];

    try {
      Directory backupDir;
      if (location == 'downloads') {
        backupDir = await _getDownloadsDirectory();
      } else {
        backupDir = await _getDefaultBackupDirectory();
      }

      final noteappBackupsDir = Directory(
        join(backupDir.path, 'noteapp_backups'),
      );
      if (!await noteappBackupsDir.exists()) {
        return backups;
      }

      final files = await noteappBackupsDir.list().where((entity) {
        return entity is File &&
            entity.path.endsWith('.db') &&
            entity.path.contains('noteapp_backup');
      }).toList();

      for (final file in files) {
        final path = file.path;
        final fileName = path.split('/').last;

        DateTime? timestamp;
        final timestampMatch = RegExp(
          r'(\d{4})_(\d{2})_(\d{2})T(\d{2})_(\d{2})_(\d{2})',
        ).firstMatch(fileName);
        if (timestampMatch != null) {
          try {
            final year = int.parse(timestampMatch.group(1)!);
            final month = int.parse(timestampMatch.group(2)!);
            final day = int.parse(timestampMatch.group(3)!);
            final hour = int.parse(timestampMatch.group(4)!);
            final minute = int.parse(timestampMatch.group(5)!);
            final second = int.parse(timestampMatch.group(6)!);
            timestamp = DateTime(year, month, day, hour, minute, second);
          } catch (_) {}
        }

        String? displayName;
        final nameMatch = RegExp(
          r'noteapp_backup_(.+)_\d{4}_\d{2}_\d{2}T',
        ).firstMatch(fileName);
        if (nameMatch != null) {
          displayName = nameMatch.group(1)!.replaceAll('_', ' ');
        }

        backups.add({
          'path': path,
          'fileName': fileName,
          'location': locationName,
          'timestamp': timestamp,
          'displayName': displayName,
        });
      }
    } catch (_) {}

    return backups;
  }

  Future<String?> getStoredBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_backupPathKey);
  }

  Future<void> setStoredBackupPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_backupPathKey, path);
    } else {
      await prefs.remove(_backupPathKey);
    }
  }

  Future<List<Map<String, String>>> getAvailableStorageLocations() async {
    final locations = <Map<String, String>>[];

    if (!kIsWeb && Platform.isAndroid) {
      locations.add({
        'name': '下载目录',
        'path': 'downloads',
        'description': '可在文件管理器中查看',
      });
    }

    return locations;
  }

  Future<Directory> _getBackupDirectory(String? customPath) async {
    String? path = customPath;

    if (path == null || path.isEmpty) {
      path = await getStoredBackupPath();
    }

    Directory dir;

    if (path == 'downloads') {
      dir = await _getDownloadsDirectory();
    } else if (path != null && path.isNotEmpty) {
      dir = Directory(path);
      bool canUse = true;

      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (e) {
          debugPrint('Failed to create custom backup directory: $e');
          canUse = false;
        }
      }

      if (canUse) {
        try {
          final testFile = File(join(dir.path, '.test_write'));
          await testFile.writeAsString('test');
          await testFile.delete();
        } catch (e) {
          debugPrint('No write permission for custom backup directory: $e');
          canUse = false;
        }
      }

      if (!canUse) {
        await setStoredBackupPath(null);
        dir = await _getDefaultBackupDirectory();
      }
    } else {
      dir = await _getDefaultBackupDirectory();
    }

    final backupDir = Directory(join(dir.path, 'noteapp_backups'));
    await backupDir.create(recursive: true);
    return backupDir;
  }

  Future<Directory> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final possiblePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      for (final p in possiblePaths) {
        final dir = Directory(p);
        if (await dir.exists()) {
          try {
            final testFile = File(join(p, '.test_write'));
            await testFile.writeAsString('test');
            await testFile.delete();
            return dir;
          } catch (e) {
            debugPrint('Cannot write to $p: $e');
            continue;
          }
        }
      }
    }

    return await _getDefaultBackupDirectory();
  }

  Future<Directory> _getDefaultBackupDirectory() async {
    if (!kIsWeb) {
      try {
        final externalStorage = await getExternalStorageDirectory();
        if (externalStorage != null) {
          return externalStorage;
        }
      } catch (e) {
        debugPrint('Failed to get external storage directory: $e');
      }
    }
    return await getApplicationDocumentsDirectory();
  }

  Future _closeDatabase() async {
    // 由主类实现
  }
}
