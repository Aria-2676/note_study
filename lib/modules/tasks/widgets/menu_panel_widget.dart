import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../models/task_model.dart';
import './advanced_search_panel_widget.dart';
import './filter_panel_widget.dart';
import './search_results_widget.dart';

class MenuPanelWidget extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(DateTime) scrollCalendarToDate;

  const MenuPanelWidget({
    super.key,
    required this.onClose,
    required this.scrollCalendarToDate,
  });

  @override
  State<MenuPanelWidget> createState() => _MenuPanelWidgetState();
}

class _MenuPanelWidgetState extends State<MenuPanelWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String _currentSearchQuery = '';
  bool _isSearchMode = false;
  bool _isFilterExpanded = false;
  String? _selectedPriorityFilter;
  bool? _selectedCompletionFilter;
  bool? _selectedRecurrenceFilter;

  bool _showAdvancedSearch = false;
  DateTime? _searchStartDate;
  DateTime? _searchEndDate;
  bool? _searchCompletionStatus;

  @override
  void initState() {
    super.initState();
    final taskProvider = context.read<TaskProvider>();
    _currentSearchQuery = taskProvider.searchQuery;
    _searchController.text = _currentSearchQuery;
    _selectedPriorityFilter = taskProvider.priorityFilter;
    _selectedCompletionFilter = taskProvider.completionFilter;
    _selectedRecurrenceFilter = taskProvider.recurrenceFilter;

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
      _showAdvancedSearch = false;
      _searchStartDate = null;
      _searchEndDate = null;
      _searchCompletionStatus = null;
    });
    context.read<TaskProvider>().exitSearchMode();
  }

  void _performAdvancedSearch() {
    context.read<TaskProvider>().advancedSearch(
      query: _currentSearchQuery,
      startDate: _searchStartDate,
      endDate: _searchEndDate,
      completionStatus: _searchCompletionStatus,
    );
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
            _buildSearchBar(colorScheme),
            if (_showAdvancedSearch) _buildAdvancedSearchPanel(colorScheme),
            Flexible(
              child: _isSearchMode
                  ? _buildSearchResults(taskProvider)
                  : _buildMenuButtons(taskProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme colorScheme) {
    return Padding(
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
                prefixIcon: _isSearchMode ? null : const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_currentSearchQuery.isNotEmpty || _showAdvancedSearch)
                      IconButton(
                        icon: Icon(
                          _showAdvancedSearch
                              ? Icons.filter_list
                              : Icons.filter_list_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _showAdvancedSearch = !_showAdvancedSearch;
                          });
                        },
                      ),
                    if (_currentSearchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      ),
                  ],
                ),
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
    );
  }

  Widget _buildAdvancedSearchPanel(ColorScheme colorScheme) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.35),
      child: SingleChildScrollView(
        child: AdvancedSearchPanelWidget(
          searchStartDate: _searchStartDate,
          searchEndDate: _searchEndDate,
          searchCompletionStatus: _searchCompletionStatus,
          onStartDateSelected: (date) {
            setState(() {
              _searchStartDate = date;
            });
            _performAdvancedSearch();
          },
          onEndDateSelected: (date) {
            setState(() {
              _searchEndDate = date;
            });
            _performAdvancedSearch();
          },
          onCompletionStatusChanged: (status) {
            setState(() {
              _searchCompletionStatus = status;
            });
            _performAdvancedSearch();
          },
          onClear: () {
            setState(() {
              _searchStartDate = null;
              _searchEndDate = null;
              _searchCompletionStatus = null;
            });
            _performAdvancedSearch();
          },
        ),
      ),
    );
  }

  Widget _buildSearchResults(TaskProvider taskProvider) {
    return SearchResultsWidget(
      taskProvider: taskProvider,
      currentSearchQuery: _currentSearchQuery,
      onClear: _clearSearch,
      onTaskTap: _navigateToTaskDetail,
    );
  }

  Widget _buildMenuButtons(TaskProvider taskProvider) {
    final screenHeight = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
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
                const SizedBox(width: 16),
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
                const SizedBox(width: 16),
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
                const SizedBox(width: 16),
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
          ),
          if (_isFilterExpanded)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenHeight * 0.4),
              child: SingleChildScrollView(
                child: _buildFilterPanel(taskProvider),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(TaskProvider taskProvider) {
    return FilterPanelWidget(
      taskProvider: taskProvider,
      selectedPriorityFilter: _selectedPriorityFilter,
      selectedCompletionFilter: _selectedCompletionFilter,
      selectedRecurrenceFilter: _selectedRecurrenceFilter,
      onPriorityChanged: (priority) {
        setState(() {
          _selectedPriorityFilter = priority;
        });
        taskProvider.setPriorityFilter(priority);
        context.read<SettingsProvider>().setLastPriorityFilter(priority);
      },
      onCompletionChanged: (completion) {
        setState(() {
          _selectedCompletionFilter = completion;
        });
        taskProvider.setCompletionFilter(completion);
        context.read<SettingsProvider>().setLastCompletionFilter(completion);
      },
      onRecurrenceChanged: (recurrence) {
        setState(() {
          _selectedRecurrenceFilter = recurrence;
        });
        taskProvider.setRecurrenceFilter(recurrence);
        context.read<SettingsProvider>().setLastRecurrenceFilter(recurrence);
      },
      onClear: () {
        setState(() {
          _selectedPriorityFilter = null;
          _selectedCompletionFilter = null;
          _selectedRecurrenceFilter = null;
        });
        taskProvider.clearFilters();
      },
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
