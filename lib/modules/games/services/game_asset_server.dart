import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/utils/app_logger.dart';

/// 单个游戏的本地静态文件服务。
///
/// 游戏包解压后若直接用 `file://` 加载，WebView 的 `fetch`/`XHR` 取子资源会被
/// 同源策略拦截，导致依赖外部素材的游戏无法运行。因此这里在应用内起一个
/// **仅绑定 IPv4 回环、端口由系统分配**的 HTTP 服务，让游戏以普通同源站点方式运行。
///
/// 注意：本实现不支持 HTTP `Range` 请求，`<audio>`/`<video>` 会退化为整体下载；
/// 当前休闲小游戏无大音频，可接受。
class GameAssetServer {
  HttpServer? _server;
  String? _root;

  /// 服务是否正在运行。
  bool get isRunning => _server != null;

  /// 当前监听端口；未启动时为 0。
  int get port => _server?.port ?? 0;

  /// 请求路径前导斜杠；`p.join` 会把前导 `/` 视为 rooted，必须先剥掉。
  static final RegExp _leadingSlashes = RegExp(r'^/+');

  static const Map<String, String> _mimeTypes = {
    '.html': 'text/html; charset=utf-8',
    '.htm': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.mjs': 'text/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
    '.map': 'application/json; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon',
    '.mp3': 'audio/mpeg',
    '.ogg': 'audio/ogg',
    '.wav': 'audio/wav',
    '.woff': 'font/woff',
    '.woff2': 'font/woff2',
    '.ttf': 'font/ttf',
    '.wasm': 'application/wasm',
    '.txt': 'text/plain; charset=utf-8',
  };

  /// 启动服务并返回游戏入口的完整地址。
  ///
  /// [rootDir] 为游戏版本目录，[entry] 为入口文件相对路径。
  /// 重复调用会先停止既有服务，避免端口泄漏。
  Future<Uri> start({required String rootDir, required String entry}) async {
    await stop();

    final root = Directory(rootDir).absolute.path;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _root = root;
    _server = server;
    server.listen(
      _handle,
      onError: (Object error) => AppLogger.warn('GameAssetServer', 'listen', error),
    );
    return Uri.parse('http://127.0.0.1:${server.port}/$entry');
  }

  /// 停止服务并释放端口。
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _root = null;
    if (server == null) return;
    try {
      await server.close(force: true);
    } catch (error) {
      AppLogger.warn('GameAssetServer', 'close', error);
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      await _serve(request, response);
    } catch (error, stack) {
      AppLogger.warn('GameAssetServer', 'serve ${request.uri}', error, stack);
      try {
        response.statusCode = HttpStatus.internalServerError;
      } catch (_) {
        // 响应头已发出，无法再改状态码，忽略。
      }
    } finally {
      try {
        await response.close();
      } catch (_) {
        // 连接可能已被客户端关闭，忽略。
      }
    }
  }

  Future<void> _serve(HttpRequest request, HttpResponse response) async {
    final root = _root;
    if (root == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      return;
    }
    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      return;
    }

    final target = _resolveTarget(root, request.uri.path);
    if (target == null) {
      response.statusCode = HttpStatus.forbidden;
      return;
    }

    final file = File(target);
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      return;
    }

    response.headers
      ..set(
        HttpHeaders.contentTypeHeader,
        _mimeTypes[p.extension(target).toLowerCase()] ??
            'application/octet-stream',
      )
      ..set(HttpHeaders.cacheControlHeader, 'no-store')
      // 显式给出长度：WebView 需要它才能显示资源加载进度，部分内核在缺少
      // `Content-Length` 时还会先缓冲整个响应再解析。
      ..contentLength = await file.length();

    if (request.method == 'HEAD') return;
    await response.addStream(file.openRead());
  }

  /// 将请求路径解析为 root 内的绝对文件路径；越界时返回 null。
  String? _resolveTarget(String root, String rawPath) {
    var decoded = Uri.decodeComponent(rawPath);
    // 目录请求（以 `/` 结尾）回落为目录下的入口文件。
    if (decoded.endsWith('/')) decoded = '${decoded}index.html';
    // `p.join` 遇到以 `/` 开头的段会替换整个路径（各平台都把前导 `/` 视为
    // rooted），因此必须先剥离前导斜杠，否则子资源请求会被误判为越界。
    final trimmed = decoded.replaceFirst(_leadingSlashes, '');
    if (trimmed.trim().isEmpty) {
      return p.join(root, 'index.html');
    }
    final normalized = p.normalize(p.join(root, trimmed));
    final relative = p.relative(normalized, from: root);
    if (relative.startsWith('..') || p.isAbsolute(relative)) return null;
    return normalized;
  }
}