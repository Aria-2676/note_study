import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/games/utils/game_version_utils.dart';

void main() {
  group('GameVersionUtils', () {
    test('should parse a plain three-segment version', () {
      expect(GameVersionUtils.parse('1.2.3'), [1, 2, 3]);
    });

    test('should parse version with v prefix', () {
      expect(GameVersionUtils.parse('v1.2.3'), [1, 2, 3]);
    });

    test('should ignore pre-release suffix', () {
      expect(GameVersionUtils.parse('1.2.3-beta.1'), [1, 2, 3]);
    });

    test('should pad missing segments with zero', () {
      expect(GameVersionUtils.parse('1.2'), [1, 2, 0]);
      expect(GameVersionUtils.parse('1'), [1, 0, 0]);
    });

    test('should return zeros for unparseable input', () {
      expect(GameVersionUtils.parse('abc'), [0, 0, 0]);
    });

    test('should compare numerically instead of lexically', () {
      expect(GameVersionUtils.compare('1.10.0', '1.9.9'), greaterThan(0));
      expect(GameVersionUtils.isNewer('1.10.0', '1.9.9'), isTrue);
    });

    test('should treat identical versions as equal', () {
      expect(GameVersionUtils.compare('2.0.0', '2.0.0'), 0);
      expect(GameVersionUtils.isNewer('2.0.0', '2.0.0'), isFalse);
    });

    test('should detect older candidate version', () {
      expect(GameVersionUtils.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(GameVersionUtils.isNewer('1.0.0', '1.0.1'), isFalse);
    });

    test('should validate version strings containing digits', () {
      expect(GameVersionUtils.isValid('1.0.0'), isTrue);
      expect(GameVersionUtils.isValid('v2'), isTrue);
      expect(GameVersionUtils.isValid('beta'), isFalse);
      expect(GameVersionUtils.isValid(''), isFalse);
    });
  });
}