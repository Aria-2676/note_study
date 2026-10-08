import 'package:shared_preferences/shared_preferences.dart';

/// 「每日一次免费刮奖」的领取记录。
///
/// 只保存**最近一次领取的本地日期**（`yyyy-MM-dd`），因此判定天然按自然日重置，
/// 无需定时任务；这是纯本地福利，不涉及服务端时间。
class ScratchFreeTicketRepository {
  static const String _lastDateKey = 'scratch_free_ticket_last_date';

  /// 今天是否仍可用免费机会。
  Future<bool> isFreeAvailable() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastDateKey) != _todayKey();
    } catch (_) {
      // 读取失败时按「不可用」处理，避免异常放大成重复领取。
      return false;
    }
  }

  /// 标记今天的免费机会已领取。
  Future<void> markUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastDateKey, _todayKey());
    } catch (_) {
      // 写入失败时忽略：极端情况最多多领一次本地福利。
    }
  }

  /// 本地自然日标识。
  static String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}