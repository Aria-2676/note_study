import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_backup_mixin.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';

/// 被测对象：把 [DatabaseBackupMixin] 组合到内存 SQLite 上。
///
/// 备份逻辑本身只操作文件系统与 SharedPreferences，`database` getter 只是为了
/// 满足 mixin 契约（这里不会被调用），因此用内存库即可。
class _TestDb with DatabaseBackupMixin implements DatabaseGateway {
  @override
  final String dbName = 'test.db';

  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 3, onCreate: (db, _) async {}),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  String? docsPath;

  late Directory dbRootDir;
  late Directory docsDir;
  late Directory backupsDir;
  late _TestDb db;

  setUpAll(() async {
    // path_provider 在测试环境没有原生实现，用方法通道桩让
    // `getApplicationDocumentsDirectory()` 指向临时目录。
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory' ||
              call.method == 'getTemporaryDirectory') {
            return docsPath;
          }
          return null;
        });

    dbRootDir = Directory.systemTemp.createTempSync('v5_backup_db_');
    await databaseFactoryFfi.setDatabasesPath(dbRootDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    try {
      dbRootDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// 写入“源数据库文件”，`backupDatabase` 只会检查存在并复制它。
  void seedSourceDb() {
    File(join(dbRootDir.path, 'test.db')).writeAsStringSync('source-db-bytes');
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = _TestDb();
    docsDir = Directory.systemTemp.createTempSync('v5_backup_docs_');
    docsPath = docsDir.path;
    backupsDir = Directory(join(docsDir.path, 'noteapp_backups'));
    seedSourceDb();
  });

  tearDown(() async {
    await db.close();
    try {
      docsDir.deleteSync(recursive: true);
    } catch (_) {}
    try {
      File(join(dbRootDir.path, 'test.db')).deleteSync();
    } catch (_) {}
  });

  group('DatabaseBackupMixin', () {
    test('should copy the database file into the backup directory', () async {
      final path = await db.backupDatabase(backupName: '我的备份');

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsStringSync(), 'source-db-bytes');
      expect(path, contains('noteapp_backup_'));
      expect(File(path).parent.path, backupsDir.path);
    });

    test('should throw when the source database file is missing', () async {
      File(join(dbRootDir.path, 'test.db')).deleteSync();

      expect(db.backupDatabase(), throwsA(isA<Exception>()));
    });

    test('should list backup files newest name first', () async {
      await db.backupDatabase(customPath: docsDir.path, backupName: 'a');
      await db.backupDatabase(customPath: docsDir.path, backupName: 'b');

      final files = await db.getBackupFiles(customPath: docsDir.path);
      expect(files.length, 2);
      // 文件名前缀 noteapp_backup_a / _b，倒序排列时 b 在前
      expect(files.first, contains('noteapp_backup_b'));
    });

    test('should return an empty list when no backups exist', () async {
      final files = await db.getBackupFiles(customPath: docsDir.path);
      expect(files, isEmpty);
    });

    test('should rename a backup and keep its timestamp', () async {
      final original = await db.backupDatabase(
        customPath: docsDir.path,
        backupName: 'old',
      );

      final renamed = await db.renameBackup(original, backupName: '新名字');

      expect(renamed, isNotNull);
      expect(File(renamed!).existsSync(), isTrue);
      expect(File(original).existsSync(), isFalse);
      expect(renamed, contains('新名字'));
      expect(
        RegExp(r'noteapp_backup_新名字_\d{4}_\d{2}_\d{2}T\d{2}_\d{2}_\d{2}\.db$')
            .hasMatch(renamed),
        isTrue,
      );
    });

    test('should strip the display name when backupName is null', () async {
      final original = await db.backupDatabase(
        customPath: docsDir.path,
        backupName: 'old',
      );

      final renamed = await db.renameBackup(original);

      expect(renamed, isNotNull);
      expect(
        RegExp(r'noteapp_backup_\d{4}_\d{2}_\d{2}T\d{2}_\d{2}_\d{2}\.db$')
            .hasMatch(renamed!),
        isTrue,
      );
    });

    test('should return null when renaming a missing file', () async {
      final result = await db.renameBackup(join(docsDir.path, 'missing.db'));
      expect(result, isNull);
    });

    test('should return null when the file name has no timestamp', () async {
      backupsDir.createSync(recursive: true);
      final plain = File(join(backupsDir.path, 'plain.db'))
        ..writeAsStringSync('x');

      expect(await db.renameBackup(plain.path), isNull);
    });

    test('should import a valid backup over the database file', () async {
      final source = File(join(docsDir.path, 'import_source.db'))
        ..writeAsStringSync('imported-bytes');

      final ok = await db.importDatabase(source.path);

      expect(ok, isTrue);
      expect(
        File(join(dbRootDir.path, 'test.db')).readAsStringSync(),
        'imported-bytes',
      );
    });

    test('should return false when importing a missing path', () async {
      final ok = await db.importDatabase(join(docsDir.path, 'nope.db'));
      expect(ok, isFalse);
    });

    test('should store, replace and clear the backup path', () async {
      await db.setStoredBackupPath('/tmp/custom');
      expect(await db.getStoredBackupPath(), '/tmp/custom');

      await db.setStoredBackupPath('');
      expect(await db.getStoredBackupPath(), isNull);

      await db.setStoredBackupPath('/tmp/custom');
      await db.setStoredBackupPath(null);
      expect(await db.getStoredBackupPath(), isNull);
    });

    test('should collect all backups sorted by timestamp desc', () async {
      backupsDir.createSync(recursive: true);
      File(join(backupsDir.path, 'noteapp_backup_alpha_2026_01_02T03_04_05.db'))
          .writeAsStringSync('x');
      File(join(backupsDir.path, 'noteapp_backup_beta_2026_02_03T04_05_06.db'))
          .writeAsStringSync('x');
      // 非 .db 文件不应被收集
      File(join(backupsDir.path, 'notes.txt')).writeAsStringSync('x');

      final all = await db.getAllBackupFiles();

      expect(all, isNotEmpty);
      expect(all.first['timestamp'], DateTime(2026, 2, 3, 4, 5, 6));
      expect(all.first['displayName'], 'beta');
      expect(all.last['timestamp'], DateTime(2026, 1, 2, 3, 4, 5));
      expect(all.every((e) => e['timestamp'] is DateTime), isTrue);
      expect(
        all.every((e) => (e['location'] as String).isNotEmpty),
        isTrue,
      );
    });

    test('should include any .db file inside the backups directory', () async {
      backupsDir.createSync(recursive: true);
      File(join(backupsDir.path, 'stray.db')).writeAsStringSync('x');

      final all = await db.getAllBackupFiles();

      // 生产过滤条件为 path.contains('noteapp_backup')，而所在目录名本身
      // 就是 noteapp_backups，因此该目录下任意 .db 都会被当成备份列出。
      expect(all, isNotEmpty);
      expect(
        all.every((e) => (e['fileName'] as String).endsWith('stray.db')),
        isTrue,
      );
    });

    test('should report storage locations as an empty list on host', () async {
      // 宿主测试进程不是 Android，因此没有可用的存储位置
      expect(await db.getAvailableStorageLocations(), isEmpty);
    });
  });
}