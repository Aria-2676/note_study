import 'package:flutter/foundation.dart';

/// 平台能力判定。
class GamePlatformUtils {
  const GamePlatformUtils._();

  /// 当前平台是否支持内置 WebView 容器。
  ///
  /// `webview_flutter` 仅提供 Android / iOS / macOS 实现；在 Windows、Linux
  /// 与 Web 上 `WebViewPlatform.instance` 为 null，直接构造控制器会抛异常。
  /// 因此所有涉及 WebView 的入口都必须先经过本判定。
  static bool supportsEmbeddedWebView() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }
}