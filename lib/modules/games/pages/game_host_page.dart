import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../../providers/points_provider.dart';
import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../providers/game_provider.dart';
import '../services/game_asset_server.dart';
import '../utils/game_platform_utils.dart';
import '../widgets/game_unsupported_placeholder_widget.dart';

/// 游戏容器的运行阶段。
enum GameHostStatus {
  /// 正在准备（启动本地服务、扣费）。
  booting,

  /// 当前平台不支持 WebView。
  unsupported,

  /// 积分不足，无法入场。
  insufficient,

  /// 启动失败。
  error,

  /// 游戏已就绪。
  ready,
}

/// 小游戏运行容器。
///
/// 负责：启动本地静态服务 → 扣除入场积分 → 加载 WebView → 桥接游戏消息。
/// 游戏包解压后完全离线运行，本页不依赖网络。
class GameHostPage extends StatefulWidget {
  const GameHostPage({super.key, required this.game, required this.installed});

  /// 云端清单中的游戏信息（含单价）。
  final GameInfo game;

  /// 本地安装记录（含版本与入口）。
  final InstalledGame installed;

  @override
  State<GameHostPage> createState() => _GameHostPageState();
}

class _GameHostPageState extends State<GameHostPage> {
  static const String _legacyBestScore2048Key = 'game_2048_best_score';
  static const int _maxReasonableScore = 1000000000;

  final GameAssetServer _server = GameAssetServer();
  WebViewController? _controller;
  GameHostStatus _status = GameHostStatus.booting;
  String? _errorMessage;
  int _bestScore = 0;
  int _lastReportedScore = 0;

  String get _bestScoreKey => 'game_best_score_${widget.game.id}';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!GamePlatformUtils.supportsEmbeddedWebView()) {
      setState(() => _status = GameHostStatus.unsupported);
      return;
    }

    final provider = context.read<GameProvider>();
    try {
      final directory = await provider.directoryOf(widget.installed);
      if (!await Directory(directory).exists()) {
        _fail('游戏文件缺失，请重新下载');
        return;
      }

      final entryUri = await _server.start(
        rootDir: directory,
        entry: widget.installed.entry,
      );

      _bestScore = await _loadBestScore();

      final charged = await provider.chargeEntry(widget.game);
      if (!charged) {
        setState(() => _status = GameHostStatus.insufficient);
        return;
      }

      final controller = _buildController(entryUri);
      if (!mounted) return;
      setState(() {
        _controller = controller;
        _status = GameHostStatus.ready;
      });
      await controller.loadRequest(entryUri);
    } catch (error, stack) {
      AppLogger.warn('GameHostPage', '启动游戏失败: ${widget.game.id}', error, stack);
      _fail('启动游戏失败，请稍后重试');
    }
  }

  WebViewController _buildController(Uri entryUri) {
    final allowedPrefix = 'http://127.0.0.1:${_server.port}/';
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('GameBridge', onMessageReceived: _onJsMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => request.url.startsWith(
            allowedPrefix,
          )
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onWebResourceError: (error) => AppLogger.warn(
            'GameHostPage',
            'WebView 资源错误 ${error.errorCode}: ${error.description}',
          ),
        ),
      );
  }

  void _onJsMessage(JavaScriptMessage message) {
    final Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('消息不是 JSON 对象');
      }
      payload = decoded;
    } catch (error) {
      AppLogger.warn('GameHostPage', '桥接消息解析失败', error);
      return;
    }

    switch (payload['type']) {
      case 'ready':
      case 'getUserInfo':
        _sendUserInfo(payload['requestId']);
      case 'reportScore':
        _handleScore((payload['score'] as num?)?.toInt() ?? 0);
      case 'exit':
        _exitToCenter();
      default:
        AppLogger.warn('GameHostPage', '未知桥接消息类型: ${payload['type']}');
    }
  }

  void _sendUserInfo(Object? requestId) {
    final points = context.read<PointsProvider>().currentPoints;
    _sendToGame({
      'type': 'userInfo',
      'requestId': ?requestId,
      'points': points,
      'bestScore': _bestScore,
      'gameId': widget.game.id,
    });
  }

  Future<void> _sendToGame(Map<String, dynamic> payload) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final json = jsonEncode(payload);
      await controller.runJavaScript(
        'window.__native && window.__native.onMessage($json);',
      );
    } catch (error, stack) {
      AppLogger.warn('GameHostPage', '向游戏发送消息失败', error, stack);
    }
  }

  Future<void> _handleScore(int score) async {
    if (score <= 0 || score > _maxReasonableScore) return;
    // 只接受递增的分数上报，避免游戏脚本反复回传造成统计噪声。
    if (score <= _lastReportedScore) return;
    _lastReportedScore = score;
    await context.read<GameProvider>().reportGameScore(widget.game.id, score);

    if (score <= _bestScore) return;
    _bestScore = score;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScoreKey, score);
    } catch (error) {
      AppLogger.warn('GameHostPage', '保存最高分失败', error);
    }
    _sendToGame({'type': 'bestScore', 'bestScore': score});
  }

  Future<int> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_bestScoreKey);
      if (current != null) return current;
      // 兼容旧版 Dart 实现的 2048 最高分，避免升级后记录丢失。
      if (widget.game.id == '2048') {
        final legacy = prefs.getInt(_legacyBestScore2048Key);
        if (legacy != null) {
          await prefs.setInt(_bestScoreKey, legacy);
          return legacy;
        }
      }
    } catch (error) {
      AppLogger.warn('GameHostPage', '读取最高分失败', error);
    }
    return 0;
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _status = GameHostStatus.error;
      _errorMessage = message;
    });
  }

  void _exitToCenter() {
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _sendToGame({'type': 'back'});
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.game.name), centerTitle: true),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case GameHostStatus.unsupported:
        return const GameUnsupportedPlaceholderBody();
      case GameHostStatus.insufficient:
        return _buildNotice(
          icon: Icons.savings_outlined,
          title: '积分不足',
          message: '进入「${widget.game.name}」需要 ${widget.game.cost} 积分，'
              '当前积分不足以支付。',
        );
      case GameHostStatus.error:
        return _buildNotice(
          icon: Icons.error_outline,
          title: '无法启动',
          message: _errorMessage ?? '未知错误',
        );
      case GameHostStatus.booting:
        return const Center(child: CircularProgressIndicator());
      case GameHostStatus.ready:
        final controller = _controller;
        if (controller == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return WebViewWidget(controller: controller);
    }
  }

  Widget _buildNotice({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _exitToCenter,
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}