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
import '../widgets/task_create_bottom_sheet_widget.dart';
import '../widgets/top_slide_menu_widget.dart';

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
    await context.read<PointsProvider>().initialize();
    if (!mounted) return;
    await context.read<TagProvider>().initialize();
    if (!mounted) return;
    await context.read<TaskProvider>().initialize();
    if (!mounted) return;
    await context.read<ShopProvider>().initialize();
    if (!mounted) return;
    final settingsProvider = context.read<SettingsProvider>();
    final taskProvider = context.read<TaskProvider>();
    taskProvider.syncSortOption(settingsProvider.taskSortOption);

    if (settingsProvider.rememberFilters) {
      if (settingsProvider.lastPriorityFilter != null) {
        taskProvider.setPriorityFilter(settingsProvider.lastPriorityFilter);
      }
      if (settingsProvider.lastCompletionFilter != null) {
        taskProvider.setCompletionFilter(settingsProvider.lastCompletionFilter);
      }
      if (settingsProvider.lastRecurrenceFilter != null) {
        taskProvider.setRecurrenceFilter(settingsProvider.lastRecurrenceFilter);
      }
      if (settingsProvider.lastTagFilterId != null) {
        final tagProvider = context.read<TagProvider>();
        final taskIds = await tagProvider.getTaskIdsByTag(
          settingsProvider.lastTagFilterId!,
        );
        taskProvider.selectTag(
          settingsProvider.lastTagFilterId!,
          taskIds: taskIds,
        );
      }
    }

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
      builder: (ctx) => TopSlideMenuWidget(
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
    final settingsProvider = context.read<SettingsProvider>();
    final taskProvider = context.read<TaskProvider>();
    final tagProvider = context.read<TagProvider>();

    if (settingsProvider.taskCreateMode == TaskCreateMode.minimal) {
      _showMinimalTaskDialog(context, taskProvider, tagProvider);
    } else {
      _showFullTaskBottomSheet(
        context,
        taskProvider,
        settingsProvider,
        tagProvider,
      );
    }
  }

  void _showMinimalTaskDialog(
    BuildContext context,
    TaskProvider taskProvider,
    TagProvider tagProvider,
  ) {
    final titleController = TextEditingController();
    final selectedDate = taskProvider.selectedDate;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('快速添加任务'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: '输入任务名称',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.add_task),
          ),
          autofocus: true,
          onSubmitted: (_) => _createMinimalTask(
            ctx,
            titleController,
            taskProvider,
            selectedDate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => _createMinimalTask(
              ctx,
              titleController,
              taskProvider,
              selectedDate,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _createMinimalTask(
    BuildContext dialogContext,
    TextEditingController titleController,
    TaskProvider taskProvider,
    DateTime selectedDate,
  ) {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务名称')));
      return;
    }

    final task = Task(title: title, cplTime: selectedDate);

    taskProvider.addTask(task);
    Navigator.of(dialogContext).pop();
  }

  void _showFullTaskBottomSheet(
    BuildContext context,
    TaskProvider taskProvider,
    SettingsProvider settingsProvider,
    TagProvider tagProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TaskCreateBottomSheetWidget(
        taskProvider: taskProvider,
        settingsProvider: settingsProvider,
        tagProvider: tagProvider,
      ),
    );
  }
}
