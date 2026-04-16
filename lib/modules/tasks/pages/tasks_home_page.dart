import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';
import './task_page.dart';
import '../../statistics/pages/statistics_page.dart';
import '../../others/pages/others_page.dart';
import '../../profile/pages/profile_page.dart';
import '../models/task_model.dart';

class TasksHomePage extends StatefulWidget {
  const TasksHomePage({super.key});

  @override
  State<TasksHomePage> createState() => _TasksHomePageState();
}

class _TasksHomePageState extends State<TasksHomePage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ScrollController _calendarController = ScrollController();

  OverlayEntry? _menuOverlayEntry;
  AnimationController? _menuAnimationController;
  Animation<Offset>? _menuAnimation;
  bool _isMenuOpen = false;
  bool _isListAtTop = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProviders();
    _menuAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _menuAnimation = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _menuAnimationController!,
            curve: Curves.easeOut,
          ),
        );
  }

  Future<void> _initializeProviders() async {
    if (!mounted) return;
    await context.read<TaskProvider>().initialize();
    if (!mounted) return;
    await context.read<PointsProvider>().initialize();
    if (!mounted) return;
    await context.read<ShopProvider>().initialize();
    if (!mounted) return;
    await context.read<SettingsProvider>().initialize();
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    final taskProvider = context.read<TaskProvider>();
    taskProvider.syncSortOption(settingsProvider.taskSortOption);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scrollToToday();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarController.dispose();
    _menuAnimationController?.dispose();
    _removeMenuOverlay();
    super.dispose();
  }

  void _updateListScrollState(bool isAtTop) {
    _isListAtTop = isAtTop;
  }

  void _showMenuPanel(BuildContext context) {
    if (_isMenuOpen) return;
    _isMenuOpen = true;

    _menuOverlayEntry = OverlayEntry(
      builder: (ctx) => _TopSlideMenu(
        animation: _menuAnimation!,
        onClose: _hideMenuPanel,
        scrollCalendarToDate: _scrollCalendarToDate,
      ),
    );

    Overlay.of(context).insert(_menuOverlayEntry!);
    _menuAnimationController!.forward();
  }

  void _hideMenuPanel() {
    if (!_isMenuOpen) return;

    _menuAnimationController!.reverse().then((_) {
      _removeMenuOverlay();
      _isMenuOpen = false;
    });
  }

  void _removeMenuOverlay() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
  }

  void _handleSwipeDown(DragEndDetails details) {
    if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
      if (!_isMenuOpen) {
        _showMenuPanel(context);
      }
    }
  }

  void _handleSwipeDownFromList(DragEndDetails details) {
    if (_isListAtTop &&
        details.primaryVelocity != null &&
        details.primaryVelocity! > 300) {
      if (!_isMenuOpen) {
        _showMenuPanel(context);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<TaskProvider>().syncFromWidget();
    }
  }

  void _scrollToToday() {
    const double itemWidth = 66.0;
    const int todayIndex = 15;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (todayIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    if (_calendarController.hasClients) {
      _calendarController.animateTo(
        offset.clamp(0.0, _calendarController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _calendarController.hasClients) {
          _calendarController.animateTo(
            offset.clamp(0.0, _calendarController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _scrollCalendarToDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    const double itemWidth = 66.0;
    const int todayIndex = 15;
    final targetIndex = todayIndex + diff;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (targetIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    if (_calendarController.hasClients) {
      _calendarController.animateTo(
        offset.clamp(0.0, _calendarController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _resetToToday() {
    context.read<TaskProvider>().selectDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appStateProvider = context.watch<AppStateProvider>();
    final pointsProvider = context.watch<PointsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管家'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _showMenuPanel(context),
          tooltip: '菜单',
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${pointsProvider.currentPoints}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onVerticalDragEnd: _handleSwipeDown,
        child: IndexedStack(
          index: appStateProvider.currentTab,
          children: [
            TaskPage(
              calendarController: _calendarController,
              onResetToToday: _resetToToday,
              scrollToToday: _scrollToToday,
              onScrollStateChanged: _updateListScrollState,
              onSwipeDownFromList: _handleSwipeDownFromList,
            ),
            const StatisticsPage(),
            const OthersPage(),
            const ProfilePage(),
          ],
        ),
      ),
      floatingActionButton: appStateProvider.currentTab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddTaskDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: appStateProvider.currentTab,
        onDestinationSelected: (index) {
          appStateProvider.setCurrentTab(index);
          if (index == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _resetToToday();
            });
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.apps), label: '其他'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final settingsProvider = context.read<SettingsProvider>();
    final tagProvider = context.read<TagProvider>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _TaskCreatePage(
          taskProvider: taskProvider,
          settingsProvider: settingsProvider,
          tagProvider: tagProvider,
        ),
      ),
    );
  }
}

class _TaskCreatePage extends StatefulWidget {
  final TaskProvider taskProvider;
  final SettingsProvider settingsProvider;
  final TagProvider tagProvider;

  const _TaskCreatePage({
    required this.taskProvider,
    required this.settingsProvider,
    required this.tagProvider,
  });

  @override
  State<_TaskCreatePage> createState() => _TaskCreatePageState();
}

class _TaskCreatePageState extends State<_TaskCreatePage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  String _recurrence = 'none';
  String _priority = 'white';
  bool _isWord = false;
  final List<int> _selectedTagIds = [];

  bool _shouldShowField(String key) {
    if (widget.settingsProvider.taskCreateMode == TaskCreateMode.minimal) {
      return false;
    }
    if (widget.settingsProvider.taskCreateMode == TaskCreateMode.full) {
      return true;
    }
    return widget.settingsProvider.isFieldEnabled(key);
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.taskProvider.selectedDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _createTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务名称')));
      return;
    }

    final task = Task(
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      cplTime: _selectedDate,
      rewardPoints: int.tryParse(_pointsController.text) ?? 0,
      recurrence: _recurrence,
      priority: _priority,
      isWord: _isWord,
    );

    final createdTask = await widget.taskProvider.addTask(task);

    if (_selectedTagIds.isNotEmpty && createdTask.id != null) {
      await widget.tagProvider.setTagsForTask(createdTask.id!, _selectedTagIds);
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加任务'),
        centerTitle: true,
        actions: [TextButton(onPressed: _createTask, child: const Text('保存'))],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '任务名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),

            if (_shouldShowField('description')) ...[
              TextField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: '任务描述（可选）',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
            ],

            if (_shouldShowField('rewardPoints')) ...[
              TextField(
                controller: _pointsController,
                decoration: const InputDecoration(
                  labelText: '积分奖励',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.stars_outlined),
                  suffixText: '分',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],

            if (_shouldShowField('date')) ...[
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '任务日期',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_shouldShowField('recurrence')) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '循环设置',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.repeat),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _recurrence,
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不循环')),
                      DropdownMenuItem(value: 'daily', child: Text('每天')),
                      DropdownMenuItem(value: 'weekly', child: Text('每周')),
                      DropdownMenuItem(value: 'monthly', child: Text('每月')),
                    ],
                    onChanged: (v) => setState(() => _recurrence = v!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_shouldShowField('priority')) ...[
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '优先级',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                child: Wrap(
                  spacing: 8,
                  children:
                      [
                            {
                              'value': 'white',
                              'label': '无',
                              'color': Colors.grey,
                            },
                            {'value': 'red', 'label': '高', 'color': Colors.red},
                            {
                              'value': 'yellow',
                              'label': '中',
                              'color': Colors.amber,
                            },
                            {
                              'value': 'green',
                              'label': '低',
                              'color': Colors.green,
                            },
                          ]
                          .map(
                            (p) => ChoiceChip(
                              label: Text(p['label'] as String),
                              selected: _priority == p['value'],
                              selectedColor: (p['color'] as Color).withValues(
                                alpha: 0.3,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(
                                    () => _priority = p['value'] as String,
                                  );
                                }
                              },
                            ),
                          )
                          .toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_shouldShowField('isWord')) ...[
              SwitchListTile(
                title: const Text('单词任务'),
                subtitle: const Text('标记为单词学习任务'),
                value: _isWord,
                onChanged: (v) => setState(() => _isWord = v),
                secondary: const Icon(Icons.translate),
              ),
              const SizedBox(height: 16),
            ],

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '当前模式：${_getModeName()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModeName() {
    switch (widget.settingsProvider.taskCreateMode) {
      case TaskCreateMode.minimal:
        return '极简模式';
      case TaskCreateMode.full:
        return '完整模式';
      case TaskCreateMode.custom:
        return '自定义模式';
    }
  }
}

class _MenuPanelContent extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(DateTime) scrollCalendarToDate;

  const _MenuPanelContent({
    required this.onClose,
    required this.scrollCalendarToDate,
  });

  @override
  State<_MenuPanelContent> createState() => _MenuPanelContentState();
}

class _MenuPanelContentState extends State<_MenuPanelContent> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _currentSearchQuery = '';
  bool _isSearchMode = false;
  bool _isFilterExpanded = false;
  String? _selectedPriorityFilter;
  bool? _selectedCompletionFilter;
  bool? _selectedRecurrenceFilter;

  @override
  void initState() {
    super.initState();
    final taskProvider = context.read<TaskProvider>();
    _currentSearchQuery = taskProvider.searchQuery;
    _searchController.text = _currentSearchQuery;

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && !_isSearchMode) {
        setState(() => _isSearchMode = true);
        context.read<TaskProvider>().enterSearchMode();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    setState(() {
      _currentSearchQuery = query;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        context.read<TaskProvider>().searchAllTasks(query);
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearchQuery = '';
    });
    context.read<TaskProvider>().clearSearch();
  }

  void _exitSearchMode() {
    _searchController.clear();
    setState(() {
      _currentSearchQuery = '';
      _isSearchMode = false;
    });
    context.read<TaskProvider>().exitSearchMode();
  }

  void _navigateToTaskDetail(Task task) {
    widget.onClose();
    final taskProvider = context.read<TaskProvider>();
    taskProvider.selectDate(task.cplTime);
    widget.scrollCalendarToDate(task.cplTime);
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_isSearchMode)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _exitSearchMode,
                    ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: '搜索所有任务...',
                        prefixIcon: _isSearchMode
                            ? null
                            : const Icon(Icons.search),
                        suffixIcon: _currentSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: _isSearchMode
                  ? _buildSearchResults(taskProvider, colorScheme)
                  : _buildMenuButtons(taskProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    TaskProvider taskProvider,
    ColorScheme colorScheme,
  ) {
    if (taskProvider.isSearching) {
      return const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentSearchQuery.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Text(
            '输入关键词搜索所有任务',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      );
    }

    final results = taskProvider.searchResults;

    if (results.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '未找到匹配的任务',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _clearSearch, child: const Text('清空搜索')),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final task = results[index];
        return _buildSearchResultItem(task, colorScheme);
      },
    );
  }

  Widget _buildSearchResultItem(Task task, ColorScheme colorScheme) {
    final dateStr =
        '${task.cplTime.year}-${task.cplTime.month.toString().padLeft(2, '0')}-${task.cplTime.day.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          task.isOK ? Icons.check_circle : Icons.circle_outlined,
          color: task.isOK
              ? Colors.green
              : colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isOK ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description != null && task.description!.isNotEmpty)
              Text(
                task.description!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (task.recurrence != 'none') ...[
                  const SizedBox(width: 8),
                  Icon(Icons.repeat, size: 12, color: colorScheme.primary),
                ],
                if (task.rewardPoints > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.stars, size: 12, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    '+${task.rewardPoints}',
                    style: const TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToTaskDetail(task),
      ),
    );
  }

  Widget _buildMenuButtons(TaskProvider taskProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildMenuButton(
                context,
                icon: Icons.sort,
                label: _getSortLabel(taskProvider.sortOption),
                onTap: () {
                  widget.onClose();
                  _showSortOptions(context, taskProvider);
                },
              ),
              _buildMenuButton(
                context,
                icon: Icons.checklist,
                label: '批量操作',
                isToggled: taskProvider.batchMode,
                onTap: () {
                  taskProvider.setBatchMode(!taskProvider.batchMode);
                  widget.onClose();
                },
              ),
              _buildMenuButton(
                context,
                icon: Icons.filter_list,
                label: '筛选',
                isToggled: _isFilterExpanded,
                onTap: () {
                  setState(() {
                    _isFilterExpanded = !_isFilterExpanded;
                  });
                },
              ),
              _buildMenuButton(
                context,
                icon: Icons.refresh,
                label: '刷新',
                onTap: () {
                  taskProvider.loadTasksByDate(taskProvider.selectedDate);
                  widget.onClose();
                },
              ),
            ],
          ),
          if (_isFilterExpanded) _buildFilterPanel(taskProvider),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(TaskProvider taskProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '筛选选项',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedPriorityFilter = null;
                    _selectedCompletionFilter = null;
                    _selectedRecurrenceFilter = null;
                  });
                  taskProvider.clearFilters();
                },
                child: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('优先级', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: '全部',
                isSelected: _selectedPriorityFilter == null,
                onSelected: () {
                  setState(() {
                    _selectedPriorityFilter = null;
                  });
                  taskProvider.setPriorityFilter(null);
                },
              ),
              _buildFilterChip(
                label: '红色',
                color: Colors.red,
                isSelected: _selectedPriorityFilter == 'red',
                onSelected: () {
                  setState(() {
                    _selectedPriorityFilter = 'red';
                  });
                  taskProvider.setPriorityFilter('red');
                },
              ),
              _buildFilterChip(
                label: '黄色',
                color: Colors.orange,
                isSelected: _selectedPriorityFilter == 'yellow',
                onSelected: () {
                  setState(() {
                    _selectedPriorityFilter = 'yellow';
                  });
                  taskProvider.setPriorityFilter('yellow');
                },
              ),
              _buildFilterChip(
                label: '绿色',
                color: Colors.green,
                isSelected: _selectedPriorityFilter == 'green',
                onSelected: () {
                  setState(() {
                    _selectedPriorityFilter = 'green';
                  });
                  taskProvider.setPriorityFilter('green');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('完成状态', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: '全部',
                isSelected: _selectedCompletionFilter == null,
                onSelected: () {
                  setState(() {
                    _selectedCompletionFilter = null;
                  });
                  taskProvider.setCompletionFilter(null);
                },
              ),
              _buildFilterChip(
                label: '未完成',
                isSelected: _selectedCompletionFilter == false,
                onSelected: () {
                  setState(() {
                    _selectedCompletionFilter = false;
                  });
                  taskProvider.setCompletionFilter(false);
                },
              ),
              _buildFilterChip(
                label: '已完成',
                isSelected: _selectedCompletionFilter == true,
                onSelected: () {
                  setState(() {
                    _selectedCompletionFilter = true;
                  });
                  taskProvider.setCompletionFilter(true);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('任务类型', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _buildFilterChip(
                label: '全部',
                isSelected: _selectedRecurrenceFilter == null,
                onSelected: () {
                  setState(() {
                    _selectedRecurrenceFilter = null;
                  });
                  taskProvider.setRecurrenceFilter(null);
                },
              ),
              _buildFilterChip(
                label: '普通任务',
                isSelected: _selectedRecurrenceFilter == false,
                onSelected: () {
                  setState(() {
                    _selectedRecurrenceFilter = false;
                  });
                  taskProvider.setRecurrenceFilter(false);
                },
              ),
              _buildFilterChip(
                label: '循环任务',
                isSelected: _selectedRecurrenceFilter == true,
                onSelected: () {
                  setState(() {
                    _selectedRecurrenceFilter = true;
                  });
                  taskProvider.setRecurrenceFilter(true);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    Color? color,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: (color ?? Theme.of(context).colorScheme.primary)
          .withValues(alpha: 0.2),
      checkmarkColor: color ?? Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isToggled = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isToggled
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: isToggled
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : null,
            ),
            child: Icon(
              icon,
              color: isToggled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isToggled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getSortLabel(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.priority:
        return '按优先级';
      case TaskSortOption.completionStatus:
        return '按完成状态';
      case TaskSortOption.createdTime:
        return '按创建时间';
      case TaskSortOption.completionTime:
        return '按完成时间';
      case TaskSortOption.defaultOrder:
        return '默认排序';
    }
  }

  void _showSortOptions(BuildContext context, TaskProvider taskProvider) {
    final settingsProvider = context.read<SettingsProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '排序方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioGroup<TaskSortOption>(
              groupValue: taskProvider.sortOption,
              onChanged: (value) {
                if (value != null) {
                  taskProvider.setSortOption(value);
                  settingsProvider.setTaskSortOption(value);
                }
                Navigator.of(ctx).pop();
              },
              child: Column(
                children: TaskSortOption.values
                    .map(
                      (option) => RadioListTile<TaskSortOption>(
                        title: Text(_getSortLabel(option)),
                        value: option,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSlideMenu extends StatelessWidget {
  final Animation<Offset> animation;
  final VoidCallback onClose;
  final void Function(DateTime) scrollCalendarToDate;

  const _TopSlideMenu({
    required this.animation,
    required this.onClose,
    required this.scrollCalendarToDate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Align(
            alignment: Alignment.topCenter,
            child: SlideTransition(
              position: animation,
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  color: Colors.transparent,
                  child: _MenuPanelContent(
                    onClose: onClose,
                    scrollCalendarToDate: scrollCalendarToDate,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
