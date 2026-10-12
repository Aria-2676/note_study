import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/updater/models/app_update_manifest.dart';
import 'package:v5_app/core/utils/version_utils.dart';

void main() {
  group('AppUpdateManifest', () {
    test('根节点不是对象时应抛 FormatException', () {
      expect(() => AppUpdateManifest.fromJson('nope'), throwsFormatException);
      expect(() => AppUpdateManifest.fromJson(null), throwsFormatException);
    });

    test('应解析出整包版本与各平台产物', () {
      final manifest = AppUpdateManifest.fromJson({
        'schemaVersion': 2,
        'updatedAt': '2026-10-09T14:30:00Z',
        'minSupported': '5.0.0',
        'latest': {
          'version': '6.0.0',
          'level': 'major',
          'notes': ['新增坦克大战', '修复白屏'],
          'downloads': {
            'android': {
              'url': 'https://example.com/a.apk',
              'sha256': 'ABCDEF',
              'sizeBytes': 1024,
            },
          },
        },
      });

      expect(manifest.schemaVersion, 2);
      expect(manifest.updatedAt, isNotNull);
      expect(manifest.minSupported, '5.0.0');
      expect(manifest.release!.version, '6.0.0');
      expect(manifest.release!.declaredLevel, VersionChangeLevel.major);
      expect(manifest.release!.notes, ['新增坦克大战', '修复白屏']);
      // sha256 统一转小写，避免大小写不一致导致校验误判。
      expect(manifest.release!.downloads['android']!.sha256, 'abcdef');
      expect(manifest.release!.downloads['android']!.sizeBytes, 1024);
    });

    test('minSupported 不含数字时应视为未设置', () {
      final manifest = AppUpdateManifest.fromJson({
        'minSupported': 'next',
      });
      expect(manifest.minSupported, isNull);
    });

    test('latest 版本号非法时丢弃整包，但不影响 assets', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {'version': 'vNext'},
        'assets': {'build': 7, 'url': 'https://example.com/a.zip'},
      });
      expect(manifest.release, isNull);
      expect(manifest.assets, isNotNull);
      expect(manifest.assets!.build, 7);
    });

    test('downloads 里非 http(s) 地址应被丢弃', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {
          'version': '6.0.0',
          'downloads': {
            'android': {'url': 'https://ok.com/a.apk'},
            'windows': {'url': 'file:///C:/evil.exe'},
            'ios': {'url': 'javascript:alert(1)'},
          },
        },
      });

      final downloads = manifest.release!.downloads;
      expect(downloads.containsKey('android'), isTrue);
      expect(downloads.containsKey('windows'), isFalse);
      expect(downloads.containsKey('ios'), isFalse);
    });

    test('downloads 全部非法时该版本仍存在但没有平台可用', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {
          'version': '6.0.0',
          'downloads': {
            'android': {'url': 'ftp://x/a.apk'},
          },
        },
      });
      expect(manifest.release, isNotNull);
      expect(manifest.release!.supportsPlatform('android'), isFalse);
    });

    test('notes 支持用换行分隔的字符串', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {
          'version': '6.0.0',
          'notes': '第一条\n\n  第二条  \n',
        },
      });
      expect(manifest.release!.notes, ['第一条', '第二条']);
    });

    test('level 缺省时按版本号差值推断', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {'version': '6.0.0'},
      });
      final release = manifest.release!;
      expect(release.declaredLevel, isNull);
      expect(release.levelAgainst('5.5.10'), VersionChangeLevel.major);
      expect(release.levelAgainst('6.0.0'), VersionChangeLevel.patch);
    });

    test('level 显式声明优先于推断', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {'version': '5.5.11', 'level': 'major'},
      });
      expect(
        manifest.release!.levelAgainst('5.5.10'),
        VersionChangeLevel.major,
      );
    });

    test('level 写了非法值时应回落到推断', () {
      final manifest = AppUpdateManifest.fromJson({
        'latest': {'version': '5.5.11', 'level': 'huge'},
      });
      expect(manifest.release!.declaredLevel, isNull);
      expect(
        manifest.release!.levelAgainst('5.5.10'),
        VersionChangeLevel.patch,
      );
    });

    test('assets 构建号必须为正整数', () {
      expect(
        AppUpdateManifest.fromJson({
          'assets': {'build': 0, 'url': 'https://x/a.zip'},
        }).assets,
        isNull,
      );
      expect(
        AppUpdateManifest.fromJson({
          'assets': {'build': -1, 'url': 'https://x/a.zip'},
        }).assets,
        isNull,
      );
      expect(
        AppUpdateManifest.fromJson({
          'assets': {'build': '3', 'url': 'https://x/a.zip'},
        }).assets,
        isNull,
      );
    });

    test('assets 地址非法时丢弃', () {
      expect(
        AppUpdateManifest.fromJson({
          'assets': {'build': 3, 'url': 'file:///C:/x.zip'},
        }).assets,
        isNull,
      );
    });

    test('应忽略未知字段（例如 _comment）', () {
      final manifest = AppUpdateManifest.fromJson({
        '_comment': ['随便写点什么'],
        'latest': {'version': '6.0.0'},
      });
      expect(manifest.release!.version, '6.0.0');
    });

    test('toJson → fromJson 往返应保持一致', () {
      final source = AppUpdateManifest.fromJson({
        'schemaVersion': 1,
        'minSupported': '5.0.0',
        'latest': {
          'version': '6.0.0',
          'level': 'minor',
          'notes': ['a'],
          'downloads': {
            'android': {'url': 'https://x/a.apk', 'sha256': 'FF', 'sizeBytes': 9},
          },
        },
        'assets': {'build': 3, 'url': 'https://x/a.zip', 'sha256': 'AA'},
      });

      final roundTrip = AppUpdateManifest.fromJson(source.toJson());
      expect(roundTrip.schemaVersion, source.schemaVersion);
      expect(roundTrip.minSupported, source.minSupported);
      expect(roundTrip.release!.version, source.release!.version);
      expect(roundTrip.release!.declaredLevel, source.release!.declaredLevel);
      expect(roundTrip.release!.notes, source.release!.notes);
      expect(
        roundTrip.release!.downloads['android']!.sha256,
        source.release!.downloads['android']!.sha256,
      );
      expect(roundTrip.assets!.build, source.assets!.build);
      expect(roundTrip.assets!.sha256, source.assets!.sha256);
    });

    test('hasAnyUpdate 反映是否解析出任何内容', () {
      expect(AppUpdateManifest.fromJson({}).hasAnyUpdate, isFalse);
      expect(
        AppUpdateManifest.fromJson({
          'assets': {'build': 1, 'url': 'https://x/a.zip'},
        }).hasAnyUpdate,
        isTrue,
      );
    });
  });
}
