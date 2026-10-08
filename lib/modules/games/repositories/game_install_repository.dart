import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/app_logger.dart';
import '../models/installed_game_model.dart';

/// 游戏文件与安装索引的持久化。
///
/// 存放在应用私有支持目录下：
/// ```
/// <ApplicationSupport>/games/
///   installed_games.json     # 索引（仅作缓存）
///   .tmp/                    # 下载与解压的临时区
///   <gameId>/<version>/...   # 已安装的游戏版本目录
/// ```
/// 真实数据源始终是磁盘上的版本目录，索引损坏或缺失时可由调用方扫描重建。
class GameInstallRepository {
  /// [baseDirectoryProvider] 用于注入根目录来源，默认取应用支持目录；
  /// 单元测试可注入临时目录，避免依赖平台通道。
  GameInstallRepository({Future<Directory> Function()? baseDirectoryProvider})
    : _baseDirectoryProvider =
          baseDirectoryProvider ?? getApplicationSupportDirectory;

  static const String _rootDirName = 'games';
  static const String _indexFileName = 'installed_games.json';
  static const String _tmpDirName = '.tmp';

  final Future<Directory> Function() _baseDirectoryProvider;

  /// 游戏根目录（不存在时自动创建）。
  Future<Directory> rootDirectory() async {
    final base = await _baseDirectoryProvider();
    final dir = Directory(p.join(base.path, _rootDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 临时目录，用于下载 zip 与解压中间产物。
  Future<Directory> tempDirectory() async {
    final root = await rootDirectory();
    final dir = Directory(p.join(root.path, _tmpDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// 某个游戏某个版本的安装目录路径。
  Future<String> versionDirectory(String gameId, String version) async {
    final root = await rootDirectory();
    return p.join(root.path, gameId, version);
  }

  /// 读取安装索引；文件不存在或已损坏时返回空索引。
  Future<InstalledGamesIndex> loadIndex() async {
    try {
      final root = await rootDirectory();
      final file = File(p.join(root.path, _indexFileName));
      if (!await file.exists()) return InstalledGamesIndex.empty;
      final decoded = jsonDecode(await file.readAsString());
      return InstalledGamesIndex.fromJson(decoded);
    } catch (error, stack) {
      AppLogger.warn(
        'GameInstallRepository',
        '安装索引损坏，将回退为空索引',
        error,
        stack,
      );
      return InstalledGamesIndex.empty;
    }
  }

  /// 写入安装索引（先写临时文件再替换，避免写入中断产生半截 JSON）。
  Future<void> saveIndex(InstalledGamesIndex index) async {
    final root = await rootDirectory();
    final file = File(p.join(root.path, _indexFileName));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(index.toJson()), flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temp.rename(file.path);
  }

  /// 列出某游戏在磁盘上实际存在的版本目录名。
  Future<List<String>> listInstalledVersions(String gameId) async {
    try {
      final root = await rootDirectory();
      final dir = Directory(p.join(root.path, gameId));
      if (!await dir.exists()) return [];
      final names = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          names.add(p.basename(entity.path));
        }
      }
      return names;
    } catch (error, stack) {
      AppLogger.warn(
        'GameInstallRepository',
        '扫描已安装版本失败: $gameId',
        error,
        stack,
      );
      return [];
    }
  }

  /// 删除某游戏的全部版本目录。
  Future<void> deleteGameDirectories(String gameId) async {
    try {
      final root = await rootDirectory();
      final dir = Directory(p.join(root.path, gameId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (error, stack) {
      AppLogger.warn(
        'GameInstallRepository',
        '删除游戏目录失败: $gameId',
        error,
        stack,
      );
    }
  }

  /// 删除某游戏的某个版本目录（用于升级后清理旧版本）。
  Future<void> deleteVersionDirectory(String gameId, String version) async {
    try {
      final dir = Directory(await versionDirectory(gameId, version));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (error, stack) {
      AppLogger.warn(
        'GameInstallRepository',
        '删除旧版本目录失败: $gameId@$version',
        error,
        stack,
      );
    }
  }

  /// 清理临时目录中的残留文件。
  Future<void> cleanTemp() async {
    try {
      final dir = await tempDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    } catch (error, stack) {
      AppLogger.warn('GameInstallRepository', '清理临时目录失败', error, stack);
    }
  }
}