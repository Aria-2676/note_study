import 'package:sqflite/sqflite.dart';

/// 数据库访问网关抽象
///
/// 提供数据库连接和事务能力，便于 Repository 构造注入与测试 Mock。
/// 具体实现由 [DatabaseService] 完成，通过 implements 关系暴露。
abstract class DatabaseGateway {
  /// 获取数据库实例
  Future<Database> get database;

  /// 在事务中执行操作
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action);
}
