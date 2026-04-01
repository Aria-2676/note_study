import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';
import '../models/user_points.dart';
import '../models/shop_item.dart';
import '../models/purchased_item.dart';
import '../models/recycled_task.dart';
import './database_service.dart';

class DataMigrationService {
  static const String exportFileName = 'taskmaster_backup.json';
  
  // 导出数据为JSON文件
  static Future<String?> exportData() async {
    try {
      // 获取所有数据
      final tasks = await DatabaseService.instance.getAllTasks();
      final recycledTasks = await DatabaseService.instance.getRecycledTasks();
      final userPoints = await DatabaseService.instance.getUserPoints();
      final shopItems = await DatabaseService.instance.getAllShopItems();
      final purchasedItems = await DatabaseService.instance.getPurchasedItems();
      final settings = await DatabaseService.instance.getSettings();
      
      // 构建导出数据结构
      final exportData = {
        'version': '5.2.0',
        'exportDate': DateTime.now().toIso8601String(),
        'tasks': tasks.map((task) => task.toMap()).toList(),
        'recycledTasks': recycledTasks.map((task) => task.toMap()).toList(),
        'userPoints': userPoints.toMap(),
        'shopItems': shopItems.map((item) => item.toMap()).toList(),
        'purchasedItems': purchasedItems.map((item) => item.toMap()).toList(),
        'settings': settings,
      };
      
      // 转换为JSON字符串
      final jsonString = jsonEncode(exportData);
      
      // 获取存储路径
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      final filePath = '${directory.path}/$exportFileName';
      final file = File(filePath);
      
      // 写入文件
      await file.writeAsString(jsonString);
      
      return filePath;
    } catch (e) {
      print('导出数据失败: $e');
      return null;
    }
  }
  
  // 导入数据从JSON文件
  static Future<bool> importData(String filePath) async {
    try {
      // 读取文件
      final file = File(filePath);
      if (!file.existsSync()) return false;
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      // 验证数据格式
      if (!data.containsKey('version') || !data.containsKey('tasks')) {
        return false;
      }
      
      // 创建数据备份
      final backupPath = await _createBackup();
      if (backupPath == null) {
        print('创建备份失败');
        return false;
      }
      
      // 开始事务
      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        try {
          // 清空现有数据
          await txn.rawDelete('DELETE FROM tasks');
          await txn.rawDelete('DELETE FROM recycled_tasks');
          await txn.rawDelete('DELETE FROM user_points');
          await txn.rawDelete('DELETE FROM shop_items');
          await txn.rawDelete('DELETE FROM purchased_items');
          await txn.rawDelete('DELETE FROM settings');
          
          // 导入任务
          if (data.containsKey('tasks')) {
            final tasks = (data['tasks'] as List).map((item) => Task.fromMap(item)).toList();
            for (final task in tasks) {
              await DatabaseService.instance.insertTask(task);
            }
          }
          
          // 导入回收站任务
          if (data.containsKey('recycledTasks')) {
            final recycledTasks = (data['recycledTasks'] as List).map((item) => RecycledTask.fromMap(item)).toList();
            for (final task in recycledTasks) {
              await DatabaseService.instance.insertRecycledTask(task);
            }
          }
          
          // 导入用户积分
          if (data.containsKey('userPoints')) {
            final userPoints = UserPoints.fromMap(data['userPoints']);
            await DatabaseService.instance.updateUserPoints(userPoints.points);
          }
          
          // 导入商城商品
          if (data.containsKey('shopItems')) {
            final shopItems = (data['shopItems'] as List).map((item) => ShopItem.fromMap(item)).toList();
            for (final item in shopItems) {
              await DatabaseService.instance.insertShopItem(item);
            }
          }
          
          // 导入已购买商品
          if (data.containsKey('purchasedItems')) {
            final purchasedItems = (data['purchasedItems'] as List).map((item) => PurchasedItem.fromMap(item)).toList();
            for (final item in purchasedItems) {
              await DatabaseService.instance.insertPurchasedItem(item);
            }
          }
          
          // 导入设置
          if (data.containsKey('settings')) {
            final settings = data['settings'] as Map<String, dynamic>;
            for (final entry in settings.entries) {
              await DatabaseService.instance.insertSetting(entry.key, entry.value.toString());
            }
          }
        } catch (e) {
          print('事务执行失败: $e');
          // 事务会自动回滚
          rethrow;
        }
      });
      
      return true;
    } catch (e) {
      print('导入数据失败: $e');
      return false;
    }
  }
  
  // 检查导出文件是否存在
  static Future<bool> exportFileExists() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return false;
      
      final filePath = '${directory.path}/$exportFileName';
      final file = File(filePath);
      return file.existsSync();
    } catch (e) {
      return false;
    }
  }
  
  // 获取导出文件路径
  static Future<String?> getExportFilePath() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      return '${directory.path}/$exportFileName';
    } catch (e) {
      return null;
    }
  }
  
  // 创建数据备份
  static Future<String?> _createBackup() async {
    try {
      // 获取所有数据
      final tasks = await DatabaseService.instance.getAllTasks();
      final recycledTasks = await DatabaseService.instance.getRecycledTasks();
      final userPoints = await DatabaseService.instance.getUserPoints();
      final shopItems = await DatabaseService.instance.getAllShopItems();
      final purchasedItems = await DatabaseService.instance.getPurchasedItems();
      final settings = await DatabaseService.instance.getSettings();
      
      // 构建备份数据结构
      final backupData = {
        'version': '5.2.0',
        'backupDate': DateTime.now().toIso8601String(),
        'tasks': tasks.map((task) => task.toMap()).toList(),
        'recycledTasks': recycledTasks.map((task) => task.toMap()).toList(),
        'userPoints': userPoints.toMap(),
        'shopItems': shopItems.map((item) => item.toMap()).toList(),
        'purchasedItems': purchasedItems.map((item) => item.toMap()).toList(),
        'settings': settings,
      };
      
      // 转换为JSON字符串
      final jsonString = jsonEncode(backupData);
      
      // 获取存储路径
      final directory = await getExternalStorageDirectory();
      if (directory == null) return null;
      
      final backupFileName = 'taskmaster_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final backupPath = '${directory.path}/$backupFileName';
      final file = File(backupPath);
      
      // 写入文件
      await file.writeAsString(jsonString);
      
      print('备份创建成功: $backupPath');
      return backupPath;
    } catch (e) {
      print('创建备份失败: $e');
      return null;
    }
  }
}
