part of 'task_form_widget.dart';

/// 表单的字段状态与初始化逻辑。
///
/// 其余 mixin（[TaskFormSubmitMixin]）声明 `on ... TaskFormFieldsMixin`，
/// 因此可共享这些控制器与字段值。
mixin TaskFormFieldsMixin on State<TaskFormWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController(text: '0');

  DateTime _selectedDate = DateTime.now();
  String _recurrence = 'none';
  String _priority = 'white';
  bool _isWord = false;
  Set<int> _selectedTagIds = {};

  bool get _isEditing => widget.task != null;

  bool get _isFullMode {
    if (_isEditing) {
      return widget.settingsProvider.taskEditMode == TaskEditMode.full;
    }
    return widget.settingsProvider.taskCreateMode == TaskCreateMode.full;
  }

  bool get _isMinimalMode {
    if (_isEditing) {
      return widget.settingsProvider.taskEditMode == TaskEditMode.minimal;
    }
    return widget.settingsProvider.taskCreateMode == TaskCreateMode.minimal;
  }

  bool _shouldShowField(String key) {
    if (_isFullMode) return true;
    if (_isMinimalMode) return false;
    return _isEditing
        ? widget.settingsProvider.isEditFieldEnabled(key)
        : widget.settingsProvider.isFieldEnabled(key);
  }

  void _initFields() {
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descController.text = task.description ?? '';
      _pointsController.text = task.rewardPoints.toString();
      _selectedDate = task.cplTime;
      _recurrence = task.recurrence;
      _priority = task.priority;
      _isWord = task.isWord;
      _loadTaskTags();
    } else {
      _selectedDate = widget.taskProvider.selectedDate;
    }
  }

  Future<void> _loadTaskTags() async {
    if (widget.task?.id != null) {
      final tags = await widget.tagProvider.getTagsForTask(widget.task!.id!);
      if (mounted) {
        setState(() {
          _selectedTagIds = tags.map((t) => t.id!).toSet();
        });
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await DatePickerUtils.showThreeBoxDatePicker(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }
}
