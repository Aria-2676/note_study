// 更新渠道隔离。
//
// 两件事必须成立，否则"V5 和 V6 各自维护"只是一句口号：
//   1. 清单地址不同（否则 V6 发版会推给 V5 用户）
//   2. 本地状态不同（否则资源包构建号串了，V6 会永久静默跳过热更）

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v5_app/core/updater/services/app_update_service.dart';
import 'package:v5_app/core/updater/services/app_update_settings.dart';
import 'package:v5_app/core/updater/update_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('渠道定义', () {
    test('两条渠道读不同的清单', () {
      expect(UpdateChannel.v5.manifestPath, 'update.json');
      expect(UpdateChannel.v6.manifestPath, 'update_v6.json');
      expect(UpdateChannel.v5.manifestPath, isNot(UpdateChannel.v6.manifestPath));
    });

    test('V5 渠道的本地状态沿用原键名（空前缀）', () {
      expect(UpdateChannel.v5.settingsScope, isEmpty);
      expect(UpdateChannel.v6.settingsScope, 'v6');
    });

    test('createService 出来的 service 记住自己的清单名', () {
      expect(UpdateChannel.v5.createService().manifestPath, 'update.json');
      expect(UpdateChannel.v6.createService().manifestPath, 'update_v6.json');
    });
  });

  group('候选地址跟着清单名走', () {
    test('每条候选都指向 v6 清单', () {
      final uris = AppUpdateService.candidatesFor('update_v6.json');
      expect(uris, isNotEmpty);
      for (final uri in uris) {
        expect(uri.path.endsWith('/update_v6.json'), isTrue,
            reason: '宁可少一个源，也不能退到 V5 的清单上');
      }
    });

    test('Contents API 兜底地址同样按清单名生成', () {
      expect(
        AppUpdateService.contentsApiUri('update_v6.json').toString(),
        endsWith('/contents/update_v6.json'),
      );
      expect(
        AppUpdateService.contentsApiUri('update.json').toString(),
        endsWith('/contents/update.json'),
      );
    });

    test('默认 service 仍然读 V5 清单（老调用点行为不变）', () {
      expect(AppUpdateService().manifestPath, 'update.json');
    });
  });

  group('本地状态隔离', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('默认前缀写进原键名，一个字符都不变', () async {
      const settings = AppUpdateSettings();
      await settings.setIgnoredVersion('6.0.0');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_update_ignored_version'), '6.0.0');
    });

    test('v6 前缀写到自己的键上，读不到 V5 的记录', () async {
      const v5 = AppUpdateSettings();
      const v6 = AppUpdateSettings(scope: 'v6');

      await v5.setIgnoredVersion('5.5.26');
      await v6.setIgnoredVersion('6.0.0');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_update_ignored_version'), '5.5.26');
      expect(prefs.getString('app_update_v6_ignored_version'), '6.0.0');
      expect(await v5.ignoredVersion(), '5.5.26');
      expect(await v6.ignoredVersion(), '6.0.0');
    });

    test('资源包构建号互不影响（串了会永久跳过 V6 热更）', () async {
      const v5 = AppUpdateSettings();
      const v6 = AppUpdateSettings(scope: 'v6');

      await v5.setAssetBuild(7);
      expect(await v6.assetBuild(), 0, reason: 'V6 没应用过任何资源包');
      expect(await v5.assetBuild(), 7);
    });

    test('关闭提醒也只在本渠道生效', () async {
      const v5 = AppUpdateSettings();
      const v6 = AppUpdateSettings(scope: 'v6');

      await v5.setNotificationsEnabled(false);
      expect(await v6.notificationsEnabled(), isTrue);
    });
  });
}
