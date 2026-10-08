import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/games/adapters/game_statistic_adapter.dart';

void main() {
  late GameStatisticAdapter adapter;

  setUp(() {
    adapter = GameStatisticAdapter();
  });

  group('GameStatisticAdapter', () {
    test('should be instantiable', () {
      expect(adapter, isNotNull);
    });

    test('reportPageViewCenter should not throw', () {
      expect(() => adapter.reportPageViewCenter(), returnsNormally);
    });

    test('reportDownload should not throw with valid gameId', () {
      expect(() => adapter.reportDownload('2048'), returnsNormally);
    });

    test('reportLaunch should not throw with valid parameters', () {
      expect(() => adapter.reportLaunch('2048', 10), returnsNormally);
    });

    test('reportUninstall should not throw with valid gameId', () {
      expect(() => adapter.reportUninstall('2048'), returnsNormally);
    });

    test('reportInstalled should not throw with valid parameters', () {
      expect(() => adapter.reportInstalled('2048', '1.0.0'), returnsNormally);
    });

    test('reportPointsSpent should not throw with valid parameters', () {
      expect(() => adapter.reportPointsSpent('2048', 10), returnsNormally);
    });

    test('reportScore should not throw with valid parameters', () {
      expect(() => adapter.reportScore('2048', 4096), returnsNormally);
    });
  });
}