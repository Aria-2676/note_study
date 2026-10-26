import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/plugin_bridge.dart';

/// 启动一个插件所需的全部材料。
class PluginLaunchSpec {
  const PluginLaunchSpec({
    required this.title,
    required this.entryPath,
    required this.bridge,
  });

  final String title;
  final String entryPath;
  final PluginBridge bridge;
}

/// 插件页的**内容部分**，不含 Scaffold/AppBar。
///
/// 拆出来的原因：插件既可以当一个"打开就进"的页面（[PluginPage]），
/// 也可以**直接当首页**（嵌进主包外壳的内容区）。两种情况只有外壳不同，
/// WebView、桥接、加载回调必须完全一样 —— 否则"当首页时某个接口不好使"
/// 这类问题会只在一种形态下复现。
class PluginView extends StatefulWidget {
  const PluginView({
    super.key,
    required this.entryPath,
    required this.bridge,
    this.onLoaded,
    this.onError,
  });

  /// 包内入口 HTML 的绝对路径
  final String entryPath;

  final PluginBridge bridge;

  /// 首帧加载完成（**每份页面只回调一次**）。首页熔断靠它取消超时计时器。
  final ValueChanged<String>? onLoaded;

  final ValueChanged<String>? onError;

  @override
  State<PluginView> createState() => _PluginViewState();
}

class _PluginViewState extends State<PluginView> {
  late final WebViewController _controller;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    final controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(const Color(0x00000000));
    controller.addJavaScriptChannel('HostBridge', onMessageReceived: _onHostMessage);
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) => controller.runJavaScript(_bootstrap),
        // 再补一次：有的机型 onPageStarted 时 JS 上下文还没建好
        onPageFinished: (url) {
          controller.runJavaScript(_bootstrap);
          if (_reported) return;
          _reported = true;
          widget.onLoaded?.call(url);
        },
        onWebResourceError: (error) {
          // 只报主文档的错：图片/字体挂了不该把首页判成失败
          if (!error.isForMainFrame.orTrue) return;
          widget.onError?.call(error.description);
        },
      ),
    );
    _controller = controller;
    controller.loadFile(widget.entryPath);
  }

  Future<void> _onHostMessage(JavaScriptMessage message) async {
    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is! Map) return;
      payload = Map<String, Object?>.from(decoded);
    } catch (_) {
      return;
    }

    final id = payload['id'];
    final method = payload['method'];
    if (id is! int || method is! String) return;

    final rawParams = payload['params'];
    final params = rawParams is Map
        ? Map<String, Object?>.from(rawParams)
        : const <String, Object?>{};

    final result = await widget.bridge.dispatch(method, params);
    if (!mounted) return;
    await _controller.runJavaScript('window.__hostResolve($id, ${jsonEncode(result)});');
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _controller);

  /// 注入到插件页面的桥接脚本。**幂等**：重复执行只会 return。
  static const String _bootstrap = r'''
(function () {
  if (window.host) return;
  var seq = 0;
  var pending = {};
  window.__hostResolve = function (id, payload) {
    var entry = pending[id];
    if (!entry) return;
    delete pending[id];
    if (payload && payload.ok) {
      entry.resolve(payload.result);
    } else {
      var error = (payload && payload.error) || {};
      entry.reject({ code: error.code || 'unknown', message: error.message || '调用失败' });
    }
  };
  window.host = {
    call: function (method, params) {
      return new Promise(function (resolve, reject) {
        var id = ++seq;
        pending[id] = { resolve: resolve, reject: reject };
        HostBridge.postMessage(JSON.stringify({ id: id, method: method, params: params || {} }));
      });
    }
  };
})();
''';
}

/// 独立打开的插件页（带标题栏）。
class PluginPage extends StatelessWidget {
  const PluginPage({
    super.key,
    required this.title,
    required this.entryPath,
    required this.bridge,
  });

  final String title;
  final String entryPath;
  final PluginBridge bridge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 16)),
      ),
      body: PluginView(entryPath: entryPath, bridge: bridge),
    );
  }
}

extension on bool? {
  /// `isForMainFrame` 在某些平台上是 null（老版本 API），当作 true 处理：
  /// 宁可多报一次错，也不要因为拿不到标志位而把真正的加载失败吞掉。
  bool get orTrue => this ?? true;
}
