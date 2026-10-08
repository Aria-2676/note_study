import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/points_provider.dart';
import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../providers/game_provider.dart';
import '../utils/game_platform_utils.dart';
import '../widgets/game_card_widget.dart';
import '../widgets/game_unsupported_placeholder_widget.dart';
import 'game_host_page.dart';

/// 游戏中心：展示云端可下载的游戏，并管理本地安装状态。
///
/// 游戏包按需下载，下载完成后**完全离线可玩**；列表刷新与包下载需要联网。
class GameCenterPage extends StatefulWidget {
  const GameCenterPage({super.key});

  @override
  State<GameCenterPage> createState() => _GameCenterPageState();
}

class _GameCenterPageState extends State<GameCenterPage> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<GameProvider>();
    await provider.reportCenterViewed();
    await provider.loadInstalled();
    if (!provider.isManifestLoaded) {
      await provider.refreshManifest();
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: isError ? Colors.red.shade400 : null,
      ),
    );
  }

  Future<void> _handleDownload(GameInfo game) async {
    final provider = context.read<GameProvider>();
    await provider.reportDownloadClicked(game.id);
    final success = await provider.installGame(game);
    if (success) {
      _showSnack('「${game.name}」安装完成');
    } else {
      _showSnack(provider.manifestError ?? '安装失败，请稍后重试', isError: true);
    }
  }

  Future<void> _handleLaunch(GameInfo game, InstalledGame installed) async {
    if (!GamePlatformUtils.supportsEmbeddedWebView()) {
      _showSnack('该平台暂不支持小游戏', isError: true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameHostPage(game: game, installed: installed),
      ),
    );
    if (!mounted) return;
    await context.read<GameProvider>().loadInstalled();
  }

  Future<void> _handleUninstall(GameInfo game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('卸载游戏'),
        content: Text('确定要卸载「${game.name}」吗？本地文件将被删除，可随时重新下载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    await context.read<GameProvider>().uninstallGame(game.id);
    _showSnack('已卸载「${game.name}」');
  }

  @override
  Widget build(BuildContext context) {
    if (!GamePlatformUtils.supportsEmbeddedWebView()) {
      return const GameUnsupportedPlaceholder();
    }

    final provider = context.watch<GameProvider>();
    final points = context.watch<PointsProvider>().currentPoints;

    return Scaffold(
      appBar: AppBar(
        title: const Text('游戏中心'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: provider.isLoadingManifest
                ? null
                : () => provider.refreshManifest(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadInstalled();
          await provider.refreshManifest();
        },
        child: _buildContent(provider, points),
      ),
    );
  }

  Widget _buildContent(GameProvider provider, int points) {
    if (provider.games.isEmpty && provider.isLoadingManifest) {
      return _buildScrollable(const Center(child: CircularProgressIndicator()));
    }
    if (provider.games.isEmpty) {
      return _buildScrollable(
        _buildEmptyState(
          provider.manifestError ?? '暂时没有可下载的游戏，请稍后再来',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _buildPointsHeader(points),
        if (provider.manifestError != null) _buildErrorBanner(provider),
        const SizedBox(height: 8),
        ...provider.games.map((game) => _buildCard(provider, game)),
        const SizedBox(height: 8),
        _buildFooterHint(),
      ],
    );
  }

  Widget _buildScrollable(Widget child) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 120), child],
    );
  }

  Widget _buildCard(GameProvider provider, GameInfo game) {
    final installed = provider.installedOf(game.id);
    return GameCardWidget(
      game: game,
      installed: installed,
      isInstalling: provider.isInstallingGame(game.id),
      hasUpdate: provider.isUpdateAvailable(game),
      progress: provider.downloadProgressOf(game.id),
      onDownload: () => _handleDownload(game),
      onLaunch: installed == null
          ? () {}
          : () => _handleLaunch(game, installed),
      onUninstall: () => _handleUninstall(game),
    );
  }

  Widget _buildPointsHeader(int points) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.stars, color: Colors.amber),
          const SizedBox(width: 8),
          Text(
            '当前积分：$points',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            '进入游戏按次消耗',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(GameProvider provider) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              provider.manifestError ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () => provider.refreshManifest(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 56,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterHint() {
    return Center(
      child: Text(
        '游戏按需下载，安装后可离线游玩',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
    );
  }
}