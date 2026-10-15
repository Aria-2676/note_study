import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/updater/models/app_update_decision.dart';
import 'package:v5_app/core/updater/models/app_update_manifest.dart';
import 'package:v5_app/core/updater/services/background_update_worker.dart';

AppUpdateDecision decisionWith({
  required AppUpdateKind kind,
  String? version,
}) {
  return AppUpdateDecision(
    kind: kind,
    release: version == null
        ? null
        : AppRelease(
            version: version,
            downloads: const {
              'android': AppDownloadTarget(
                url: 'https://example.com/app.apk',
              ),
            },
          ),
  );
}

void main() {
  group('shouldNotifyInBackground 通知闸门', () {
    test('决策为 null（没拉到清单）时不通知', () {
      expect(
        shouldNotifyInBackground(
          decision: null,
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });

    test('无更新时不通知', () {
      expect(
        shouldNotifyInBackground(
          decision: AppUpdateDecision.none,
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });

    test('仅有资源热更时不通知（本来就该静默）', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(kind: AppUpdateKind.assetsOnly),
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });

    test('有整包更新但被降级为 available（用户关闭提醒/跳过）时不通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(
            kind: AppUpdateKind.available,
            version: '5.6.0',
          ),
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });

    test('optional 更新且从未通知过 → 通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(
            kind: AppUpdateKind.optional,
            version: '5.6.0',
          ),
          lastNotifiedVersion: null,
        ),
        isTrue,
      );
    });

    test('forced 更新即使通知过别的版本也通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(
            kind: AppUpdateKind.forced,
            version: '5.0.0',
          ),
          lastNotifiedVersion: '5.6.0',
        ),
        isTrue,
      );
    });

    test('同一版本只通知一次', () {
      final decision = decisionWith(
        kind: AppUpdateKind.optional,
        version: '5.6.0',
      );
      expect(
        shouldNotifyInBackground(
          decision: decision,
          lastNotifiedVersion: null,
        ),
        isTrue,
      );
      expect(
        shouldNotifyInBackground(
          decision: decision,
          lastNotifiedVersion: '5.6.0',
        ),
        isFalse,
      );
    });

    test('升级到更新的版本后允许再次通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(
            kind: AppUpdateKind.optional,
            version: '5.6.1',
          ),
          lastNotifiedVersion: '5.6.0',
        ),
        isTrue,
      );
    });

    test('shouldPrompt 为 true 但 release 缺失的畸形结论不通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(kind: AppUpdateKind.optional),
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });

    test('版本号为空串时不通知', () {
      expect(
        shouldNotifyInBackground(
          decision: decisionWith(
            kind: AppUpdateKind.optional,
            version: '',
          ),
          lastNotifiedVersion: null,
        ),
        isFalse,
      );
    });
  });
}
