import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class ProfileStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Profile';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewSettings() async {
    await reportPageView(
      StatisticKeys.pageViewSettings,
      moduleName: _moduleName,
    );
  }

  Future<void> reportDataExport(String exportType) async {
    await reportClick(
      StatisticKeys.clickDataExport,
      value: {'exportType': exportType},
      moduleName: _moduleName,
    );
  }
}