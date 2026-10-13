import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 守护 `android/key.properties` 的 `storeFile` 转义。
///
/// 背景：`android/app/build.gradle.kts` 用 `java.util.Properties.load()` 读这个
/// 文件，而 **Java 的 Properties 会把反斜杠当转义符**：`\t` → TAB，
/// 且未识别的转义（`\D`、`\k`）会**把反斜杠直接丢掉**。于是路径
///
/// ```
/// storeFile=D:\Dev\keystore\taskmaster-release.jks     ← 单反斜杠（错）
/// ```
///
/// 被 Java 读成 `D:Devkeystore<TAB>askmaster-release.jks`，构建报
/// 「Keystore file ... not found」且路径看起来面目全非，极难定位。
/// 正确写法是**双反斜杠**（与 `local.properties` 里 flutter 自己写的
/// `sdk.dir=D:\\Dev\\SDK\\AndroidSdk` 一致）。
///
/// 本测试直接复现 Java 的转义规则，断言解析结果**等于**一个真实存在的文件路径。
/// 哨兵作用：即便将来有人手改 `key.properties`，只要写错了这里就会红。
void main() {
  /// 复现 `java.util.Properties.load()` 的反斜杠转义。
  String javaUnescape(String raw) {
    final sb = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw[i];
      if (c != r'\' || i == raw.length - 1) {
        sb.write(c);
        continue;
      }
      final n = raw[++i];
      switch (n) {
        case 't':
          sb.write('\t');
          break;
        case 'n':
          sb.write('\n');
          break;
        case 'r':
          sb.write('\r');
          break;
        case 'f':
          sb.write('\f');
          break;
        default:
          sb.write(n); // \\ -> \ ；其它 \x -> x（丢掉反斜杠）
          break;
      }
    }
    return sb.toString();
  }

  group('转义规则自检（与 Java Properties 对齐）', () {
    test('单反斜杠的 \\t 会变成 TAB —— 这就是那个 bug', () {
      final raw = 'D:${r'\'}Dev${r'\'}keystore${r'\'}taskmaster-release.jks';
      final javaRead = javaUnescape(raw);

      expect(javaRead.contains('\t'), isTrue);
      expect(javaRead, isNot(raw), reason: 'Java 读出来的和写的不是一回事');
      // 复现线上那条报错路径的尾段
      expect(javaRead.split('\t').last, 'askmaster-release.jks');
    });

    test('双反斜杠可无损往返', () {
      final single = 'D:${r'\'}Dev${r'\'}keystore${r'\'}taskmaster-release.jks';
      final doubled = single.replaceAll(r'\', r'\\');

      expect(javaUnescape(doubled), single);
      expect(javaUnescape(doubled), isNot(contains('\t')));
    });
  });

  group('android/key.properties', () {
    final file = File('android/key.properties');

    test('存在且 storeFile 解析后指向真实文件', () {
      // 该文件不入库（.gitignore 排除），CI/新克隆上可能不存在——
      // 那种情况下断言「缺失即跳过」，不制造无意义的红。
      if (!file.existsSync()) {
        markTestSkipped('android/key.properties 不存在（未配置 release 签名），跳过');
        return;
      }

      String? storeFileRaw;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final eq = trimmed.indexOf('=');
        if (eq < 0) continue;
        if (trimmed.substring(0, eq).trim() == 'storeFile') {
          storeFileRaw = trimmed.substring(eq + 1);
        }
      }

      expect(storeFileRaw, isNotNull, reason: 'key.properties 里必须有 storeFile');

      final resolved = javaUnescape(storeFileRaw!);

      expect(
        resolved.contains('\t'),
        isFalse,
        reason: 'storeFile 被解析出 TAB —— 说明路径用了单反斜杠，'
            '请改成双反斜杠（如 D:\\\\Dev\\\\keystore\\\\...）',
      );
      expect(
        File(resolved).existsSync(),
        isTrue,
        reason: 'storeFile 解析后应指向真实存在的密钥库：$resolved',
      );
    });
  });
}
