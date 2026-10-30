import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/config/legacy_v6_link.dart';

void main() {
  group('LegacyV6Link 按机型选包', () {
    test('每种 ABI 拿自己那个包，摘要和体积各是各的', () {
      for (final abi in LegacyV6Link.artifacts.keys) {
        final target = LegacyV6Link.targetFor(abi);
        final artifact = LegacyV6Link.artifacts[abi]!;

        expect(target.url, endsWith('/${artifact.file}'));
        expect(target.sha256, artifact.sha256);
        expect(target.sizeBytes, artifact.sizeBytes);
        expect(artifact.sizeBytes, lessThan(LegacyV6Link.fallback.sizeBytes));
      }
    });

    test('arm64 不是整包（62MB 那个坑）', () {
      final target = LegacyV6Link.targetFor('arm64-v8a');
      expect(target.url, contains('app-arm64-v8a-release.apk'));
      expect(target.sizeBytes, lessThan(30000000));
      expect(target.url, isNot(endsWith('app-release.apk')));
    });

    test('取不到 ABI 时回落整包，而不是报错', () {
      for (final unknown in <String?>[null, '', 'mips']) {
        final target = LegacyV6Link.targetFor(unknown);
        expect(target.url, endsWith('/app-release.apk'));
        expect(target.sha256, LegacyV6Link.fallback.sha256);
      }
    });

    test('镜像地址跟着选中的包走', () {
      final target = LegacyV6Link.targetFor('x86_64');
      expect(target.mirrors, isNotEmpty);
      for (final mirror in target.mirrors) {
        expect(mirror, contains('app-x86_64-release.apk'));
      }
    });

    test('确认框里的体积跟着 ABI 变', () {
      expect(LegacyV6Link.confirmBodyFor('arm64-v8a'), contains('约 21 MB'));
      expect(LegacyV6Link.confirmBodyFor(null), contains('约 59 MB'));
    });
  });
}
