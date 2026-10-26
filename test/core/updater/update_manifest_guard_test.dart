// 两份更新清单的守卫。
//
// 这里断言的不是"代码能跑"，而是**两条渠道不会被不小心合并**：
// 一旦有人把 V5 清单的 minSupported 提到 6，或者把 latest 继续往上加，
// 所有留在 5.x 的用户就会被迫升级 / 被持续打扰。这类改动在 code review 里
// 极不显眼，所以让测试来挡。
//
// 同时挡住另一端：V6 清单指向的版本不能比本地构建还新 ——
// 那说明清单写到了一个还不存在的包，用户会一直看到更新却装不上。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/utils/version_utils.dart';

Map<String, Object?> _readJson(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path 不存在');
  final decoded = jsonDecode(file.readAsStringSync());
  expect(decoded, isA<Map>(), reason: '$path 顶层必须是对象');
  return Map<String, Object?>.from(decoded as Map);
}

/// `pubspec.yaml` 里的 `version: x.y.z+build`，只取前面的版本号。
String _pubspecVersion() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  for (final line in lines) {
    if (!line.startsWith('version:')) continue;
    final raw = line.substring('version:'.length).trim();
    return raw.split('+').first;
  }
  fail('pubspec.yaml 里没有 version 行');
}

void main() {
  group('V5 渠道（update.json）', () {
    late Map<String, Object?> manifest;
    late String latest;
    late String minSupported;

    setUpAll(() {
      manifest = _readJson('update.json');
      latest = (manifest['latest']! as Map)['version']! as String;
      minSupported = manifest['minSupported']! as String;
    });

    test('最低支持版本不能越过 5.x —— 越过去就等于强制更新', () {
      expect(
        VersionUtils.parse(minSupported).first,
        lessThanOrEqualTo(5),
        reason:
            'minSupported 提到 6 会让 V5 用户无法「跳过此版本」，'
            '而 6.0.0 只能定位成"可选的引流"，不能是强制。',
      );
    });

    test('最新版本不能超过 6.0.0 —— V5 渠道冻结在这一版', () {
      expect(
        VersionUtils.compare(latest, '6.0.0'),
        lessThanOrEqualTo(0),
        reason:
            'V5 清单只负责把用户送到 6.0.0；之后的版本属于 update_v6.json。'
            '这里跟着涨就等于两条线又合并了。',
      );
    });
  });

  group('V6 渠道（update_v6.json）', () {
    late Map<String, Object?> manifest;
    late String latest;

    setUpAll(() {
      manifest = _readJson('update_v6.json');
      latest = (manifest['latest']! as Map)['version']! as String;
    });

    test('结构版本与 V5 清单一致', () {
      expect(manifest['schemaVersion'], _readJson('update.json')['schemaVersion']);
    });

    test('清单里的版本不能比本地构建更新（那会指向还不存在的包）', () {
      expect(
        VersionUtils.compare(latest, _pubspecVersion()),
        lessThanOrEqualTo(0),
        reason: '发版顺序：先改 pubspec 构建、传包、最后才改这里',
      );
    });

    test('downloads 里只要有产物，就必须带 url 与 sha256', () {
      final downloads =
          ((manifest['latest']! as Map)['downloads'] as Map?) ?? const {};
      for (final entry in downloads.entries) {
        final target = Map<String, Object?>.from(entry.value as Map);
        expect(target['url'], isA<String>(), reason: '${entry.key} 缺 url');
        expect(target['sha256'], isA<String>(), reason: '${entry.key} 缺 sha256');
        expect(
          (target['sha256']! as String).length,
          64,
          reason: '${entry.key} 的 sha256 不是 64 位十六进制',
        );
        expect(target['sizeBytes'], isA<int>(), reason: '${entry.key} 缺 sizeBytes');
      }
    });
  });
}
