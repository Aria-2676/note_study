/// 小游戏模块的可预期失败。
///
/// 覆盖清单获取、下载、校验、解压、安装等环节；[message] 可直接展示给用户。
class GameException implements Exception {
  /// 失败原因（面向用户可读）。
  final String message;

  const GameException(this.message);

  @override
  String toString() => 'GameException: $message';
}