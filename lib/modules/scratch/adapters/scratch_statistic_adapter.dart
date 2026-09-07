import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class ScratchStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Scratch';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewHome() async {
    await reportPageView(
      StatisticKeys.pageViewScratchHome,
      moduleName: _moduleName,
    );
  }

  Future<void> reportBuyTicket(int cost) async {
    await reportClick(
      StatisticKeys.clickScratchBuyTicket,
      value: {'cost': cost},
      moduleName: _moduleName,
    );
  }

  Future<void> reportStartScratch() async {
    await reportClick(
      StatisticKeys.clickScratchStart,
      moduleName: _moduleName,
    );
  }

  Future<void> reportWin(int prizeValue, String prizeType) async {
    await reportCount(
      StatisticKeys.countScratchWin,
      value: {'prizeValue': prizeValue, 'prizeType': prizeType},
      moduleName: _moduleName,
    );
  }

  Future<void> reportCost(int cost) async {
    await reportCount(
      StatisticKeys.countScratchCost,
      value: cost,
      moduleName: _moduleName,
    );
  }

  Future<void> reportPageViewWallet() async {
    await reportPageView(
      StatisticKeys.pageViewScratchWallet,
      moduleName: _moduleName,
    );
  }

  Future<void> reportPageViewRecords() async {
    await reportPageView(
      StatisticKeys.pageViewScratchRecords,
      moduleName: _moduleName,
    );
  }
}