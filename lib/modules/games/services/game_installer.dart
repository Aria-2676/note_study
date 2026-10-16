import '../../../core/services/file_downloader.dart';
import '../../../core/services/zip_extractor.dart';
import 'game_exception.dart';

/// 游戏包的下载、校验与解压。
///
/// 全部为静态无状态方法，便于在 [Isolate] 中执行重计算（解压/哈希），
/// 也便于单元测试直接调用。
class GameInstaller {
  const GameInstaller._();

  /// 下载 [url] 到 [destPath]，并通过 [onProgress] 回调进度。
  ///
  /// [onProgress] 的 `total` 在服务端未返回 `Content-Length` 时为 null。
  /// [isCancelled] 返回 true 时中止下载并抛出 [GameException]。
  /// [allowResume] 默认开启：中断重试时对已存在的残包带 `Range` 续传，
  /// 服务端不支持时自动降级整包重下。
  /// 实现在 [FileDownloader]（App 更新包也用同一套）；这里把
  /// [FileDownloadException] 转成 [GameException]，维持游戏模块原有的错误契约。
  static Future<void> downloadZip({
    required Uri url,
    required String destPath,
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration timeout = const Duration(seconds: 30),
    bool allowResume = true,
  }) async {
    try {
      await FileDownloader.download(
        url: url,
        destPath: destPath,
        onProgress: onProgress,
        isCancelled: isCancelled,
        timeout: timeout,
        allowResume: allowResume,
      );
    } on FileDownloadException catch (error) {
      throw GameException(error.message);
    }
  }

  /// 计算文件的 sha256（小写十六进制），流式处理避免大文件占内存。
  static Future<String> sha256OfFile(String path) {
    return FileDownloader.sha256OfFile(path);
  }

  /// 解压 [zipPath] 到 [targetDir]。
  ///
  /// 实现在 [ZipExtractor]（App 资源热更新包也用同一套）；这里把
  /// [ZipExtractorException] 转成 [GameException]，维持游戏模块原有的错误契约。
  static Future<void> extractZip({
    required String zipPath,
    required String targetDir,
  }) async {
    try {
      await ZipExtractor.extract(zipPath: zipPath, targetDir: targetDir);
    } on ZipExtractorException catch (error) {
      throw GameException(error.message);
    }
  }

  /// 统计目录总字节数（递归）。
  static Future<int> directorySize(String dirPath) {
    return ZipExtractor.directorySize(dirPath);
  }
}