/// 统计类型枚举
/// 定义项目中所有统计埋点的类型
enum StatisticType {
  /// 页面访问埋点
  pageView,

  /// 点击行为埋点
  click,

  /// 业务计数埋点
  count,

  /// 系统异常/基础信息埋点
  system,
}

/// 统计数据模型
/// 用于封装所有统计上报的数据结构
class StatisticData {
  /// 统计项key，必须遵循命名规则
  final String key;

  /// 统计类型
  final StatisticType type;

  /// 统计值：计数用int、行为用Map、系统用String
  final dynamic value;

  /// 事件发生的UTC时间
  final DateTime time;

  StatisticData({
    required this.key,
    required this.type,
    required this.value,
    DateTime? time,
  }) : time = time ?? DateTime.now().toUtc();

  /// 转换为Map用于存储
  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'type': type.name,
      'value': value is Map ? value : value.toString(),
      'time': time.toIso8601String(),
    };
  }

  /// 从Map创建实例
  factory StatisticData.fromMap(Map<String, dynamic> map) {
    return StatisticData(
      key: map['key'] as String,
      type: StatisticType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StatisticType.system,
      ),
      value: map['value'],
      time: DateTime.parse(map['time'] as String),
    );
  }
}

/// 统计项key常量定义
/// 所有统计项必须在此登记，避免重复
class StatisticKeys {
  // ========== Task模块 ==========
  /// 任务首页访问
  static const pageViewTaskHome = 'page_view_task_home';

  /// 任务完成按钮点击
  static const clickTaskComplete = 'click_task_complete';

  /// 累计完成任务数
  static const countTaskCompleted = 'count_task_completed';

  /// 任务创建
  static const clickTaskCreate = 'click_task_create';

  /// 任务删除
  static const clickTaskDelete = 'click_task_delete';

  // ========== Shop模块 ==========
  /// 商城首页访问
  static const pageViewShopHome = 'page_view_shop_home';

  /// 商品兑换按钮点击
  static const clickShopExchange = 'click_shop_exchange';

  /// 商城仓库访问
  static const pageViewShopWarehouse = 'page_view_shop_warehouse';

  // ========== Points模块 ==========
  /// 积分增加总数
  static const countPointsIncrease = 'count_points_increase';

  /// 积分减少总数
  static const countPointsDecrease = 'count_points_decrease';

  /// 积分页面访问
  static const pageViewPointsHome = 'page_view_points_home';

  // ========== Tag模块 ==========
  /// 标签管理页面访问
  static const pageViewTagManagement = 'page_view_tag_management';

  /// 标签创建
  static const clickTagCreate = 'click_tag_create';

  /// 标签删除
  static const clickTagDelete = 'click_tag_delete';

  // ========== Profile模块 ==========
  /// 设置页面访问
  static const pageViewSettings = 'page_view_settings';

  /// 数据导出
  static const clickDataExport = 'click_data_export';

  // ========== Pomodoro模块 ==========
  /// 番茄钟页面访问
  static const pageViewPomodoroHome = 'page_view_pomodoro_home';

  /// 番茄钟启动
  static const clickPomodoroStart = 'click_pomodoro_start';

  /// 番茄钟暂停
  static const clickPomodoroPause = 'click_pomodoro_pause';

  /// 番茄钟重置
  static const clickPomodoroReset = 'click_pomodoro_reset';

  /// 番茄钟完成计数
  static const countPomodoroCompleted = 'count_pomodoro_completed';

  /// 番茄钟专注时长
  static const countPomodoroFocusMinutes = 'count_pomodoro_focus_minutes';

  /// 番茄钟设置修改
  static const clickPomodoroSettings = 'click_pomodoro_settings';

  /// 番茄钟历史记录访问
  static const pageViewPomodoroHistory = 'page_view_pomodoro_history';

  // ========== Scratch模块 ==========
  /// 刮刮乐页面访问
  static const pageViewScratchHome = 'page_view_scratch_home';

  /// 购买彩票点击
  static const clickScratchBuyTicket = 'click_scratch_buy_ticket';

  /// 开始刮奖点击
  static const clickScratchStart = 'click_scratch_start';

  /// 中奖计数
  static const countScratchWin = 'count_scratch_win';

  /// 消耗积分计数
  static const countScratchCost = 'count_scratch_cost';

  /// 彩票夹访问
  static const pageViewScratchWallet = 'page_view_scratch_wallet';

  /// 抽奖记录访问
  static const pageViewScratchRecords = 'page_view_scratch_records';

  // ========== System系统 ==========
  /// App崩溃信息
  static const systemAppCrash = 'system_app_crash';

  /// 初始化失败
  static const systemInitFail = 'system_init_fail';

  /// 统计上报失败
  static const systemStatisticFail = 'system_statistic_fail';
}
