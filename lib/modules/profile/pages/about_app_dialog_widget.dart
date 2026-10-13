import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/updater/providers/app_update_provider.dart';

/// 关于应用弹窗。
///
/// 从 `settings_page.dart` 抽出来有两个原因：
/// 1. `_SettingsPageState` 已超过 300 行上限（项目规则），把这段 UI 移出可回落；
/// 2. 这里**本来就有**一个未使用的同名 widget，属于历史遗留的重复实现 ——
///    与其留着两份，不如让它成为唯一实现。
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  /// 便捷展示入口，避免调用方关心 showDialog 细节。
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AboutAppDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 版本号从 AppUpdateProvider 取（它已由 main.dart 注册，并用
    // package_info_plus 读过一次），不再单独调 PackageInfo ——
    // 避免重复读取，以及「两处版本来源可能不一致」的隐患。
    //
    // 显示的实用价值：验证「检查更新 → 下载 → 覆盖安装」时，
    // 不必再去系统设置里翻版本号，一眼就能确认装上的确实是新版。
    final version = context.watch<AppUpdateProvider>().currentVersion;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('关于'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('任务管家'),
          const SizedBox(height: 4),
          Text(
            version.isEmpty ? '版本 读取中…' : '版本 $version',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          const Text('一款带积分系统的任务管理应用'),
          const SizedBox(height: 8),
          const Text('功能亮点：'),
          const SizedBox(height: 4),
          const Text('• 任务管理与追踪'),
          const Text('• 积分奖励系统'),
          const Text('• 积分商城兑换'),
          const Text('• 桌面小组件支持'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
