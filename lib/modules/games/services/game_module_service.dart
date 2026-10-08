import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../repositories/game_install_repository.dart';
import '../utils/game_cdn_config.dart';
import 'game_exception.dart';
import 'game_installer.dart';

/// 小游戏模块的业务编排：清单获取、安装、卸载与状态对账。
class GameModuleService {
  GameModuleService({GameInstallRepository? installRepository})
    : _installRepository = installRepository ?? GameInstallRepository();

  final GameInstallRepository _installRepository;

  /// 拉取游戏清单。
  ///
  /// 按 [GameCdnConfig.manifestUris] 的顺序依次尝试候选地址（主 CDN → 回退），
  /// 全部失败时抛出 [GameException]。
  Future<GameManifest> fetchManifest({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    Object? lastError;
    for (final uri in GameCdnConfig.manifestUris()) {
      try {
        final body = await _httpGetString(uri, timeout);
        return GameManifest.fromJson(jsonDecode(body));
      } catch (error, stack) {
        lastError = error;
        AppLogger.warn('GameModuleService', '获取清单失败: $uri', error, stack);
      }
    }
    throw GameException('无法获取游戏列表，请检查网络连接（$lastError）');
  }

  /// 下载并安装（或升级）指定游戏，返回安装记录。
  ///
  /// 流程：下载 → sha256 校验 → 解压 → 断言入口存在 → 原子落位到版本目录 →
  /// 写索引 → 清理旧版本。失败时清理临时文件并抛出 [GameException]。
  Future<InstalledGame> install(
    GameInfo game, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final tempDir = await _installRepository.tempDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final zipPath = p.join(tempDir.path, '${game.id}-$stamp.zip');
    final extractDir = p.join(tempDir.path, '${game.id}-$stamp');

    try {
      await GameInstaller.downloadZip(
        url: GameCdnConfig.packageUri(game.package.path),
        destPath: zipPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      await _verifyChecksum(zipPath, game.package.sha256);
      await Isolate.run(
        () => GameInstaller.extractZip(zipPath: zipPath, targetDir: extractDir),
      );
      if (!await File(p.join(extractDir, game.entry)).exists()) {
        throw GameException('游戏包缺少入口文件：${game.entry}');
      }
      final targetDir = await _installRepository.versionDirectory(
        game.id,
        game.latestVersion,
      );
      await _moveIntoPlace(extractDir, targetDir);

      final size = await GameInstaller.directorySize(targetDir);
      final installed = InstalledGame(
        gameId: game.id,
        installedVersion: game.latestVersion,
        installedAt: DateTime.now(),
        sizeBytes: size,
        entry: game.entry,
      );
      final index = await _installRepository.loadIndex();
      await _installRepository.saveIndex(index.put(installed));
      await _cleanupOldVersions(game.id, game.latestVersion);
      return installed;
    } catch (error, stack) {
      AppLogger.warn('GameModuleService', '安装失败: ${game.id}', error, stack);
      if (error is GameException) rethrow;
      throw GameException('安装失败：$error');
    } finally {
      await _deleteQuietly(zipPath);
      await _deleteQuietly(extractDir);
    }
  }

  /// 卸载游戏：删除全部版本目录并从索引移除。
  Future<void> uninstall(String gameId) async {
    await _installRepository.deleteGameDirectories(gameId);
    final index = await _installRepository.loadIndex();
    await _installRepository.saveIndex(index.remove(gameId));
  }

  /// 与磁盘对账：剔除索引中记载但目录已丢失的记录。
  ///
  /// 索引只是缓存，磁盘才是真实来源；目录被系统清理或用户手动删除后，
  /// 通过本方法让状态自愈。
  Future<InstalledGamesIndex> reconcile(InstalledGamesIndex index) async {
    final valid = <String, InstalledGame>{};
    for (final entry in index.games.entries) {
      final dir = await _installRepository.versionDirectory(
        entry.value.gameId,
        entry.value.installedVersion,
      );
      if (await Directory(dir).exists()) {
        valid[entry.key] = entry.value;
      }
    }

    final result = InstalledGamesIndex(
      schemaVersion: index.schemaVersion,
      games: valid,
    );
    if (valid.length != index.games.length) {
      await _installRepository.saveIndex(result);
    }
    return result;
  }

  /// 读取安装索引（不做对账）。
  Future<InstalledGamesIndex> loadIndex() => _installRepository.loadIndex();

  /// 已安装游戏的入口目录绝对路径。
  Future<String> installedDirectory(InstalledGame game) {
    return _installRepository.versionDirectory(
      game.gameId,
      game.installedVersion,
    );
  }

  /// 清理临时目录残留。
  Future<void> cleanTemp() => _installRepository.cleanTemp();

  Future<void> _verifyChecksum(String zipPath, String expected) async {
    if (expected.isEmpty) return;
    final actual = await Isolate.run(() => GameInstaller.sha256OfFile(zipPath));
    if (actual.toLowerCase() != expected.toLowerCase()) {
      throw const GameException('游戏包校验失败，文件可能已损坏');
    }
  }

  Future<void> _moveIntoPlace(String from, String to) async {
    final target = Directory(to);
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    await Directory(p.dirname(to)).create(recursive: true);
    await Directory(from).rename(to);
  }

  Future<void> _cleanupOldVersions(String gameId, String keepVersion) async {
    final versions = await _installRepository.listInstalledVersions(gameId);
    for (final version in versions) {
      if (version != keepVersion) {
        await _installRepository.deleteVersionDirectory(gameId, version);
      }
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
    } catch (error) {
      AppLogger.warn('GameModuleService', '清理临时路径失败: $path', error);
    }
  }

  static Future<String> _httpGetString(Uri uri, Duration timeout) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw GameException('HTTP ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}