part of '../task_provider.dart';

/// 搜索、筛选与排序相关的状态变更方法。
mixin TaskQueryMixin on TaskProviderCoreMixin {
  Task? getTaskById(int id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = [];
    _isSearchMode = false;
    notifyListeners();
  }

  void enterSearchMode() {
    _isSearchMode = true;
    notifyListeners();
  }

  void exitSearchMode() {
    _isSearchMode = false;
    _searchQuery = '';
    _searchResults = [];
    notifyListeners();
  }

  void selectTag(int tagId, {List<int>? taskIds}) {
    _selectedTagId = tagId;
    _filteredTaskIds = taskIds ?? [];
    notifyListeners();
  }

  void clearTagFilter() {
    _selectedTagId = null;
    _filteredTaskIds = [];
    notifyListeners();
  }

  void setPriorityFilter(String? priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  void setCompletionFilter(bool? completion) {
    _completionFilter = completion;
    notifyListeners();
  }

  void setRecurrenceFilter(bool? recurrence) {
    _recurrenceFilter = recurrence;
    notifyListeners();
  }

  void clearFilters() {
    _priorityFilter = null;
    _completionFilter = null;
    _recurrenceFilter = null;
    notifyListeners();
  }

  Future<void> searchAllTasks(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _taskRepository.searchTasks(query);
    } catch (e) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  Future<void> advancedSearch({
    String query = '',
    DateTime? startDate,
    DateTime? endDate,
    bool? completionStatus,
  }) async {
    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _taskRepository.searchTasks(
        query,
        startDate: startDate,
        endDate: endDate,
        completionStatus: completionStatus,
      );
    } catch (e) {
      _searchResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  void setSortOption(TaskSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void syncSortOption(TaskSortOption option) => _sortOption = option;
}
