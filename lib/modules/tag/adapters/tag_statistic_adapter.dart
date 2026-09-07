import '../../../core/services/base_statistic_adapter.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

class TagStatisticAdapter extends BaseStatisticAdapter {
  static const String _moduleName = 'Tag';

  @override
  StatisticService get service => StatisticService();

  Future<void> reportPageViewManagement() async {
    await reportPageView(
      StatisticKeys.pageViewTagManagement,
      moduleName: _moduleName,
    );
  }

  Future<void> reportTagCreate(String tagName) async {
    await reportClick(
      StatisticKeys.clickTagCreate,
      value: {'tagName': tagName},
      moduleName: _moduleName,
    );
  }

  Future<void> reportTagDelete(int tagId, String tagName) async {
    await reportClick(
      StatisticKeys.clickTagDelete,
      value: {'tagId': tagId, 'tagName': tagName},
      moduleName: _moduleName,
    );
  }
}