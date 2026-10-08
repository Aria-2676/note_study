/// 游戏版本号比较工具。
///
/// 仅支持 `major.minor.patch` 三元组数值比较，不做 semver 范围匹配：
/// 清单只需回答「CDN 上的版本是否比本地新」，越简单越不容易出错。
class GameVersionUtils {
  const GameVersionUtils._();

  /// 解析版本号字符串为三元组；无法解析的部分按 0 处理。
  ///
  /// 支持 `1.2.3`、`v1.2.3`、`1.2.3-beta` 等形式，非数字后缀被忽略。
  static List<int> parse(String version) {
    final cleaned = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
    final parts = cleaned.split('.');
    final result = <int>[0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
      final match = RegExp(r'^\d+').firstMatch(parts[i]);
      result[i] = match == null ? 0 : (int.tryParse(match.group(0)!) ?? 0);
    }
    return result;
  }

  /// 比较两个版本号。
  ///
  /// 返回负数表示 [a] 更旧，0 表示相同，正数表示 [a] 更新。
  static int compare(String a, String b) {
    final left = parse(a);
    final right = parse(b);
    for (var i = 0; i < 3; i++) {
      if (left[i] != right[i]) return left[i] - right[i];
    }
    return 0;
  }

  /// 判断 [candidate] 是否比 [current] 更新。
  static bool isNewer(String candidate, String current) {
    return compare(candidate, current) > 0;
  }

  /// 版本号是否合法（至少包含一个数字）。
  static bool isValid(String version) {
    return RegExp(r'\d').hasMatch(version);
  }
}