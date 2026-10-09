import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';
import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../repositories/game_install_repository.dart';
import '../utils/game_cdn_config.dart';
import '../utils/game_version_utils.dart';
import 'game_exception.dart';
import 'game_installer.dart';

/// 小游戏模块的业务编排：清单获取、安装、卸载与状态对账。
class GameModuleService {
  GameModuleService({GameInstallRepository? installRepository})
    : _installRepository = installRepository ?? GameInstallRepository();

  /// 索引丢失后按磁盘重建时使用的默认入口名。
  static const String _defaultEntry = 'index.html';

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
      await _downloadVerifiedZip(
        game,
        zipPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
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

  /// 与磁盘对账：以磁盘为准修正索引。
  ///
  /// 索引只是缓存，磁盘才是真实来源，因此两个方向都要修：
  /// 1. 索引里记载、但目录已丢失的记录 → 剔除（被系统清理或用户手动删除）；
  /// 2. 目录存在、但索引里没有记录（索引损坏或被删）→ 补回，
  ///    否则用户明明装过却要重新下载一遍。
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

    final reconciled = await _recoverFromDisk(valid);
    final changed =
        reconciled.length != index.games.length ||
        reconciled.entries.any(
          (entry) =>
              index.games[entry.key]?.installedVersion !=
              entry.value.installedVersion,
        );

    final result = InstalledGamesIndex(
      schemaVersion: index.schemaVersion,
      games: reconciled,
    );
    if (changed) {
      await _installRepository.saveIndex(result);
    }
    return result;
  }

  /// 扫描磁盘，补回索引中缺失的安装记录。
  ///
  /// 只在版本目录内确实存在入口文件时才认账，避免把半途失败的残留目录
  /// 误判成「已安装」。索引里丢失了入口名，故统一按 `index.html` 判定。
  Future<Map<String, InstalledGame>> _recoverFromDisk(
    Map<String, InstalledGame> known,
  ) async {
    final result = Map<String, InstalledGame>.from(known);
    for (final gameId in await _installRepository.listGameIds()) {
      if (result.containsKey(gameId)) continue;
      final version = await _latestInstalledVersion(gameId);
      if (version == null) continue;
      final dir = await _installRepository.versionDirectory(gameId, version);
      if (!await File(p.join(dir, _defaultEntry)).exists()) continue;

      result[gameId] = InstalledGame(
        gameId: gameId,
        installedVersion: version,
        installedAt: DateTime.now(),
        sizeBytes: 0,
        entry: _defaultEntry,
      );
      AppLogger.warn(
        'GameModuleService',
        '安装索引缺失，已按磁盘重建: $gameId@$version',
      );
    }
    return result;
  }

  /// 磁盘上某个游戏的最新版本目录名；无有效目录时返回 null。
  Future<String?> _latestInstalledVersion(String gameId) async {
    final versions = await _installRepository.listInstalledVersions(gameId);
    if (versions.isEmpty) return null;
    versions.sort((a, b) => GameVersionUtils.compare(b, a));
    return versions.first;
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

  /// 依次尝试多个 CDN 源下载游戏包，下载后立即校验 sha256。
  ///
  /// 各镜像节点对 `@main` 的缓存彼此独立，某节点可能仍返回旧包（清单已更新、
  /// 包未更新），此时校验会失败；本方法会清理残包并回退到下一个候选源，
  /// 直至某个源返回内容与清单一致。全部失败时抛出 [GameException]。
  Future<void> _downloadVerifiedZip(
    GameInfo game,
    String zipPath, {
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    Object? lastError;
    for (final uri in GameCdnConfig.packageUris(game.package.path)) {
      try {
        await GameInstaller.downloadZip(
          url: uri,
          destPath: zipPath,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        await _verifyChecksum(zipPath, game.package.sha256);
        return;
      } catch (error, stack) {
        lastError = error;
        AppLogger.warn(
          'GameModuleService',
          '下载或校验失败，尝试下一个源: $uri',
          error,
          stack,
        );
        await _deleteQuietly(zipPath);
      }
    }
    throw GameException('游戏包下载或校验失败（$lastError）');
  }

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