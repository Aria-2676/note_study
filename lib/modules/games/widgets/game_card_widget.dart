import 'package:flutter/material.dart';

import '../models/game_manifest_model.dart';
import '../models/installed_game_model.dart';
import '../utils/game_presentation_utils.dart';

/// 游戏中心里的单个游戏卡片。
///
/// 根据安装状态呈现不同操作：未安装 → 下载；安装中 → 进度；
/// 已安装 → 开始游戏 / 卸载；有新版 → 额外提供更新。
class GameCardWidget extends StatelessWidget {
  const GameCardWidget({
    super.key,
    required this.game,
    required this.installed,
    required this.isInstalling,
    required this.hasUpdate,
    required this.progress,
    required this.onDownload,
    required this.onLaunch,
    required this.onUninstall,
  });

  /// 云端游戏信息。
  final GameInfo game;

  /// 本地安装记录；未安装为 null。
  final InstalledGame? installed;

  /// 是否正在下载/安装。
  final bool isInstalling;

  /// 是否有可用更新。
  final bool hasUpdate;

  /// 下载进度（0~1）；负值或 null 表示进度未知。
  final double? progress;

  /// 下载/更新回调。
  final VoidCallback onDownload;

  /// 启动游戏回调。
  final VoidCallback onLaunch;

  /// 卸载回调。
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final accent = GamePresentationUtils.colorFor(game.color);
    final installedGame = installed;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIcon(accent),
                const SizedBox(width: 16),
                Expanded(child: _buildTitleArea(installedGame)),
              ],
            ),
            if (isInstalling) ...[
              const SizedBox(height: 12),
              _buildProgress(accent),
            ],
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color accent) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        GamePresentationUtils.iconFor(game.icon),
        color: accent,
        size: 32,
      ),
    );
  }

  Widget _buildTitleArea(InstalledGame? installedGame) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              game.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (installedGame != null) ...[
              const SizedBox(width: 8),
              _buildChip(
                hasUpdate ? '可更新' : '已安装',
                hasUpdate ? Colors.orange : Colors.green,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          game.description,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          _buildMetaText(installedGame),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  String _buildMetaText(InstalledGame? installedGame) {
    final parts = <String>[];
    parts.add(game.cost > 0 ? '${game.cost} 积分/次' : '免费');
    if (installedGame == null) {
      parts.add(GamePresentationUtils.formatSize(game.package.sizeBytes));
    } else {
      parts.add('本地 v${installedGame.installedVersion}');
      if (hasUpdate) parts.add('最新 v${game.latestVersion}');
    }
    return parts.join(' · ');
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _buildProgress(Color accent) {
    final value = progress;
    final determinate = value != null && value >= 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: determinate ? value.clamp(0.0, 1.0) : null,
            minHeight: 6,
            backgroundColor: accent.withValues(alpha: 0.12),
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          determinate ? '下载中 ${(value * 100).toStringAsFixed(0)}%' : '正在下载…',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final installedGame = installed;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (installedGame != null)
          TextButton.icon(
            onPressed: isInstalling ? null : onUninstall,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('卸载'),
          ),
        if (installedGame == null)
          FilledButton.icon(
            onPressed: isInstalling ? null : onDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('下载'),
          )
        else ...[
          if (hasUpdate)
            OutlinedButton.icon(
              onPressed: isInstalling ? null : onDownload,
              icon: const Icon(Icons.system_update_alt, size: 18),
              label: const Text('更新'),
            ),
          FilledButton.icon(
            onPressed: isInstalling ? null : onLaunch,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('开始游戏'),
          ),
        ],
      ],
    );
  }
}