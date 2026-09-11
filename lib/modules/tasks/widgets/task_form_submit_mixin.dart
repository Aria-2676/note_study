part of 'task_form_widget.dart';

/// 表单提交：保存、新建、更新（含循环任务的「全部更新」确认）。
mixin TaskFormSubmitMixin on State<TaskFormWidget>, TaskFormFieldsMixin {
  Future<void> saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入任务名称')));
      return;
    }

    final task = Task(
      id: widget.task?.id,
      loopId: widget.task?.loopId,
      title: title,
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      cplTime: _selectedDate,
      rewardPoints: int.tryParse(_pointsController.text) ?? 0,
      recurrence: _recurrence,
      priority: _priority,
      isWord: _isWord,
      isOK: widget.task?.isOK ?? false,
      completedAt: widget.task?.completedAt,
      isDeducted: widget.task?.isDeducted ?? false,
    );

    if (_isEditing) {
      await _updateTask(task);
    } else {
      await _createTask(task);
    }
  }

  Future<void> _createTask(Task task) async {
    final createdTask = await widget.taskProvider.addTask(task);
    if (_selectedTagIds.isNotEmpty && createdTask.id != null) {
      await widget.tagProvider.setTagsForTask(
        createdTask.id!,
        _selectedTagIds.toList(),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }

  Future<void> _updateTask(Task newTask) async {
    final oldTask = widget.task!;

    if (newTask.id != null) {
      await widget.tagProvider.setTagsForTask(
        newTask.id!,
        _selectedTagIds.toList(),
      );
    }

    if (oldTask.recurrence != 'none' &&
        (oldTask.title != newTask.title ||
            oldTask.description != newTask.description ||
            oldTask.isWord != newTask.isWord ||
            oldTask.rewardPoints != newTask.rewardPoints ||
            oldTask.priority != newTask.priority ||
            oldTask.recurrence != newTask.recurrence)) {
      if (!mounted) return;
      final updateAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('更新循环任务'),
          content: const Text('是否更新所有未来的循环任务？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('仅此任务'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('全部更新'),
            ),
          ],
        ),
      );

      await widget.taskProvider.updateTask(
        newTask,
        updateAll: updateAll ?? false,
      );
    } else {
      await widget.taskProvider.updateTask(newTask);
    }

    if (mounted) {
      Navigator.of(context).pop();
      widget.onSaved?.call();
    }
  }
}
