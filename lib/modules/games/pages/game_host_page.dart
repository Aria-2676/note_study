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

  /// 同一局内分数统计的最小写入间隔（见 [_shouldReportScoreStats]）。
  static const Duration _scoreStatsInterval = Duration(seconds: 5);

  final GameAssetServer _server = GameAssetServer();
  WebViewController? _controller;
  GameHostStatus _status = GameHostStatus.booting;
  String? _errorMessage;
  int _bestScore = 0;
  int _lastReportedScore = 0;

  /// 已经写入统计的分数，用于避免同一分数重复落库。
  int _lastStatsScore = 0;

  /// 上次写入分数统计的时间。
  DateTime? _lastScoreStatsAt;

  /// 结算面板是否已弹出，避免游戏重复上报导致多次弹窗。
  bool _roundEndVisible = false;

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
        // 未能付费入场：立即释放本地服务，避免端口被空占。
        await _server.stop();
        if (!mounted) return;
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
      await _server.stop();
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
      case 'gameOver':
        _handleGameOver(payload);
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

  Future<void> _handleScore(int score, {bool isFinal = false}) async {
    if (score <= 0 || score > _maxReasonableScore) return;
    // 只接受递增的分数上报，避免游戏脚本反复回传造成统计噪声；
    // 回合结束的最终分数（[isFinal]）即使未增长也要入账。
    if (!isFinal && score <= _lastReportedScore) return;

    if (score > _lastReportedScore) _lastReportedScore = score;
    if (score > _bestScore) {
      _bestScore = score;
      await _persistBestScore(score);
      _sendToGame({'type': 'bestScore', 'bestScore': score});
    }

    if (!_shouldReportScoreStats(score, isFinal)) return;
    await context.read<GameProvider>().reportGameScore(widget.game.id, score);
  }

  /// 分数统计是否需要真正落库。
  ///
  /// 游戏会在每次得分时上报（贪吃蛇每吃一次食物就报一次），而统计写入是
  /// 「读整份缓存 → 追加 → 重写整份缓存」，逐条上报会造成明显的写放大。
  /// 因此限制为同一局内每 [_scoreStatsInterval] 最多写一次；回合结束时
  /// （[isFinal]）不受间隔限制，保证本局最终分数一定入账。
  bool _shouldReportScoreStats(int score, bool isFinal) {
    if (score <= _lastStatsScore) return false;
    final last = _lastScoreStatsAt;
    if (!isFinal &&
        last != null &&
        DateTime.now().difference(last) < _scoreStatsInterval) {
      return false;
    }
    _lastScoreStatsAt = DateTime.now();
    _lastStatsScore = score;
    return true;
  }

  /// 持久化最高分（最高分需在退出后仍然可见）。
  Future<void> _persistBestScore(int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScoreKey, score);
    } catch (error) {
      AppLogger.warn('GameHostPage', '保存最高分失败', error);
    }
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

  /// 回合结束（失败或通关）：弹出统一结算面板，由容器决定退出或付费再来一局。
  ///
  /// 游戏内不再自行提供免费重开入口，保证「一次入场 = 一个回合」。
  Future<void> _handleGameOver(Map<String, dynamic> payload) async {
    if (_roundEndVisible) return;
    _roundEndVisible = true;
    final reported = (payload['score'] as num?)?.toInt() ?? _lastReportedScore;
    // 回合结束时补报最终分数：既让最高分落库，也让统计拿到本局结果。
    await _handleScore(reported, isFinal: true);
    final won = payload['result'] == 'win';
    try {
      await _showRoundEndSheet(won);
    } finally {
      _roundEndVisible = false;
    }
  }

  /// 展示回合结算面板：「再来一局（消耗积分）」或「退出」。
  Future<void> _showRoundEndSheet(bool won) async {
    final provider = context.read<GameProvider>();
    final cost = widget.game.cost;
    var insufficient = false;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  won ? Icons.emoji_events_outlined : Icons.flag_outlined,
                  size: 44,
                  color: won ? Colors.amber : Colors.blueGrey,
                ),
                const SizedBox(height: 12),
                Text(
                  won ? '通关！' : '本局结束',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _roundSummary(),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (insufficient) ...[
                  const SizedBox(height: 8),
                  Text(
                    '积分不足，无法再来一局',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade400),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: insufficient
                        ? null
                        : () async {
                            final ok = await provider.chargeEntry(widget.game);
                            if (!ok) {
                              setSheetState(() => insufficient = true);
                              return;
                            }
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                            _lastReportedScore = 0;
                            _lastStatsScore = 0;
                            _sendToGame({'type': 'restart'});
                          },
                    child: Text('再来一局（消耗 $cost 积分）'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _exitToCenter();
                    },
                    child: const Text('退出'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 结算文案：本局有得分时同时展示得分与历史最高。
  String _roundSummary() {
    if (_lastReportedScore > 0) {
      return '本局得分 $_lastReportedScore · 最高 $_bestScore';
    }
    return '最高 $_bestScore';
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