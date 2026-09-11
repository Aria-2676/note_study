part of '../task_provider.dart';

/// 任务模块的共享状态、缓存与跨关注点公共方法。
///
/// 其余所有 mixin 都声明 `on TaskProviderCoreMixin`（或经由依赖链间接依赖它），
/// 因此都能直接访问这里的字段与方法。为了让构造函数的初始化语义保持集中，
/// [`TaskProvider`] 自身只保留构造与启动流程，其余状态都放在本 mixin。
mixin TaskProviderCoreMixin on ChangeNotifier {
  late TaskRepository _taskRepository;
  late TaskSchedulerService _taskSchedulerService;
  late PointsProvider _pointsProvider;

  List<Task> _tasks = [];
  final Map<String, List<Task>> _tasksByMonthCache = {};
  List<RecycledTask> _recycledTasks = [];
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _selectedDates = [DateTime.now()];
  bool _multiTaskMode = false;

  String _searchQuery = '';
  TaskSortOption _sortOption = TaskSortOption.defaultOrder;
  bool _batchMode = false;
  final Set<int> _selectedTaskIds = {};

  List<Task> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchMode = false;
  int? _selectedTagId;
  List<int> _filteredTaskIds = [];
  String? _priorityFilter;
  bool? _completionFilter;
  bool? _recurrenceFilter;

  List<Task> get tasks => _getFilteredAndSortedTasks();
  List<Task> get rawTasks => _tasks;
  List<RecycledTask> get recycledTasks => _recycledTasks;
  DateTime get selectedDate => _selectedDate;
  List<DateTime> get selectedDates => _selectedDates;
  bool get multiTaskMode => _multiTaskMode;
  String get searchQuery => _searchQuery;
  TaskSortOption get sortOption => _sortOption;
  bool get batchMode => _batchMode;
  Set<int> get selectedTaskIds => _selectedTaskIds;
  bool get hasSelectedTasks => _selectedTaskIds.isNotEmpty;
  List<Task> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  bool get isSearchMode => _isSearchMode;
  int? get selectedTagId => _selectedTagId;
  String? get priorityFilter => _priorityFilter;
  bool? get completionFilter => _completionFilter;
  bool? get recurrenceFilter => _recurrenceFilter;

  bool get hasActiveFilter =>
      _priorityFilter != null ||
      _completionFilter != null ||
      _recurrenceFilter != null;

  int get activeFilterCount {
    int count = 0;
    if (_priorityFilter != null) count++;
    if (_completionFilter != null) count++;
    if (_recurrenceFilter != null) count++;
    return count;
  }

  void updatePointsProvider(PointsProvider pointsProvider) {
    _pointsProvider = pointsProvider;
  }

  /// 获取指定月份的任务列表（按月懒加载，最多缓存 3 个月）
  ///
  /// 缓存采用 LRU 淘汰：命中时把该月移到队尾，淘汰时移除队首（最近最少使用的月份）。
  /// 相比 FIFO，频繁访问的月份不会因为「插入得早」被误淘汰。
  Future<List<Task>> getTasksForMonth(DateTime month) async {
    final key = _monthCacheKey(month);
    final cached = _tasksByMonthCache.remove(key);
    if (cached != null) {
      // Dart 的 Map 保持插入顺序：先移除再插回，即把该 key 置为「最近使用」。
      _tasksByMonthCache[key] = cached;
      return cached;
    }
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final tasks = await _taskRepository.getTasksByDateRange(start, end);
    if (_tasksByMonthCache.length >= 3) {
      _tasksByMonthCache.remove(_tasksByMonthCache.keys.first);
    }
    _tasksByMonthCache[key] = tasks;
    return tasks;
  }

  String _monthCacheKey(DateTime date) => '${date.year}-${date.month}';

  /// 使指定月份缓存失效（数据变更后调用）
  void _invalidateMonthCache(DateTime date) {
    _tasksByMonthCache.remove(_monthCacheKey(date));
  }

  Future<void> _loadRecycledTasks() async {
    _recycledTasks = await _taskRepository.getRecycledTasks();
    notifyListeners();
  }

  Future<void> loadRecycledTasks() async => await _loadRecycledTasks();

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Task> _getFilteredAndSortedTasks() {
    return TaskSortUtils.applyAllFilters(
      tasks: _tasks,
      priorityFilter: _priorityFilter,
      completionFilter: _completionFilter,
      recurrenceFilter: _recurrenceFilter,
      searchQuery: _searchQuery,
      filteredTaskIds: _filteredTaskIds,
      selectedTagId: _selectedTagId,
      sortOption: _sortOption,
    );
  }
}
