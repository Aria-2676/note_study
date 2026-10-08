import 'package:flutter/material.dart';

/// 当前平台不支持内置 WebView 容器时的占位页。
///
/// `webview_flutter` 仅在 Android / iOS / macOS 提供实现，Windows 与 Linux
/// 桌面端无法承载小游戏，此时展示本页而不是让页面构造控制器抛异常。
class GameUnsupportedPlaceholder extends StatelessWidget {
  const GameUnsupportedPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('小游戏'), centerTitle: true),
      body: const GameUnsupportedPlaceholderBody(),
    );
  }
}

/// 平台不支持提示的正文内容（供已有 Scaffold 的页面直接嵌入）。
class GameUnsupportedPlaceholderBody extends StatelessWidget {
  const GameUnsupportedPlaceholderBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videogame_asset_off,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '该平台暂不支持小游戏',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '小游戏依赖系统内置浏览器组件，目前仅在 Android、iOS 与 macOS 上可用。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}