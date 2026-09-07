import 'package:flutter/material.dart';
import '../modules/tag/models/tag_model.dart';
import '../core/services/database/database_service.dart';

/// 标签状态管理Provider
/// 负责标签的增删改查
class TagProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Tag> _tags = [];
  bool _initialized = false;

  List<Tag> get tags => _tags;
  List<Tag> get systemTags => _tags.where((t) => t.isSystem).toList();
  List<Tag> get customTags => _tags.where((t) => !t.isSystem).toList();
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    await _loadTags();
    if (_tags.isEmpty) {
      await _createDefaultTags();
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadTags() async {
    _tags = await _db.getAllTags();
    notifyListeners();
  }

  Future<void> _createDefaultTags() async {
    for (final tag in Tag.defaultTags) {
      await _db.insertTag(tag);
    }
    await _loadTags();
  }

  Future<void> addTag(Tag tag) async {
    await _db.insertTag(tag);
    await _loadTags();
  }

  Future<void> updateTag(Tag tag) async {
    if (tag.id == null) return;
    await _db.updateTag(tag);
    await _loadTags();
  }

  Future<void> deleteTag(int tagId) async {
    final tag = _tags.firstWhere((t) => t.id == tagId);
    if (tag.isSystem) return;
    await _db.deleteTag(tagId);
    await _db.deleteTaskTagsByTagId(tagId);
    await _loadTags();
  }

  Future<void> assignTagToTask(int taskId, int tagId) async {
    await _db.insertTaskTag(TaskTag(taskId: taskId, tagId: tagId));
  }

  Future<void> removeTagFromTask(int taskId, int tagId) async {
    await _db.deleteTaskTag(taskId, tagId);
  }

  Future<List<Tag>> getTagsForTask(int taskId) async {
    return await _db.getTagsForTask(taskId);
  }

  Future<void> setTagsForTask(int taskId, List<int> tagIds) async {
    await _db.deleteTaskTagsByTaskId(taskId);
    for (final tagId in tagIds) {
      await _db.insertTaskTag(TaskTag(taskId: taskId, tagId: tagId));
    }
  }

  Tag? getTagById(int tagId) {
    try {
      return _tags.firstWhere((t) => t.id == tagId);
    } catch (_) {
      return null;
    }
  }

  Tag? getTagByName(String name) {
    try {
      return _tags.firstWhere(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> getTaskIdsByTag(int tagId) async {
    return await _db.getTaskIdsByTag(tagId);
  }
}
