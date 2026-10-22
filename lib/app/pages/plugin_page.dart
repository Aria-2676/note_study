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

/// 页面级插件：WebView 加载包内入口 HTML，并通过 `HostBridge` 通道读宿主数据。
///
/// 桥接脚本在 `onPageStarted` 注入、`onPageFinished` 再补一次（脚本自身幂等）。
/// 插件侧应当等 `window.host` 出现再调用 —— 见 demo 插件里的 `whenHostReady`。
class PluginPage extends StatefulWidget {
  const PluginPage({
    super.key,
    required this.title,
    required this.entryPath,
    required this.bridge,
  });

  final String title;

  /// 包内入口 HTML 的绝对路径
  final String entryPath;

  final PluginBridge bridge;

  @override
  State<PluginPage> createState() => _PluginPageState();
}

class _PluginPageState extends State<PluginPage> {
  late final WebViewController _controller;

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
        onPageFinished: (_) => controller.runJavaScript(_bootstrap),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

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
