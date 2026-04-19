import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/scratch/adapters/scratch_statistic_adapter.dart';

void main() {
  late ScratchStatisticAdapter adapter;

  setUp(() {
    adapter = ScratchStatisticAdapter();
  });

  group('ScratchStatisticAdapter', () {
    test('should be instantiable', () {
      expect(adapter, isNotNull);
    });

    test('reportPageViewHome should not throw', () async {
      expect(() => adapter.reportPageViewHome(), returnsNormally);
    });

    test('reportBuyTicket should not throw with valid cost', () async {
      expect(() => adapter.reportBuyTicket(10), returnsNormally);
    });

    test('reportStartScratch should not throw', () async {
      expect(() => adapter.reportStartScratch(), returnsNormally);
    });

    test('reportWin should not throw with valid parameters', () async {
      expect(() => adapter.reportWin(50, 'integral'), returnsNormally);
    });

    test('reportCost should not throw with valid cost', () async {
      expect(() => adapter.reportCost(10), returnsNormally);
    });

    test('reportPageViewWallet should not throw', () async {
      expect(() => adapter.reportPageViewWallet(), returnsNormally);
    });

    test('reportPageViewRecords should not throw', () async {
      expect(() => adapter.reportPageViewRecords(), returnsNormally);
    });
  });
}
