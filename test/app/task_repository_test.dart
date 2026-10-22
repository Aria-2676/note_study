// v6 任务仓储的契约测试。
//
// 覆盖的是"数据落在哪儿、按什么顺序出来"这三类最容易被悄悄改坏的事：
//   1. 按日期取任务（日期是 `yyyy-MM-dd` 字符串，走索引）
//   2. 排序：未完成在前 → 优先级 → 创建时间
//   3. 删除是"拷到回收站再删原行"，不是直接删

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/app/data/demo_seed.dart';
import 'package:v5_app/app/data/task_repository.dart';
import 'package:v5_app/app/models/task.dart';
import 'package:v5_app/core/data/v6_database.dart';
import 'package:v5_app/core/data/v6_plugin_tables.dart';
import 'package:v5_app/core/data/v6_schema.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(Database, TaskRepository)> open() async {
    final db = await V6Database.open(
      path: inMemoryDatabasePath,
      pluginSchema: PluginSchemaRegistry(),
    );
    return (db, TaskRepository(db));
  }

  test('插入后按日期取回，标签一起带出', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    await repo.insertTag(const Tag(id: 0, name: '工作'));
    final tags = await repo.allTags();
    final day = DateTime(2026, 10, 22);

    await repo.insert(
      title: '写测试',
      day: day,
      estimatedMinutes: 30,
      tagIds: <int>[tags.first.id],
    );

    final list = await repo.tasksOn(day);
    expect(list, hasLength(1));
    expect(list.single.title, '写测试');
    expect(list.single.estimatedMinutes, 30);
    expect(list.single.tags.map((t) => t.name), <String>['工作']);

    // 换一天就取不到
    expect(await repo.tasksOn(day.add(const Duration(days: 1))), isEmpty);
  });

  test('完成态会写/清 completed_at', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    final day = DateTime(2026, 10, 22);
    final id = await repo.insert(title: 'A', day: day);

    await repo.setDone(id, true);
    var task = (await repo.tasksOn(day)).single;
    expect(task.isDone, isTrue);
    expect(task.completedAt, isNotNull);

    await repo.setDone(id, false);
    task = (await repo.tasksOn(day)).single;
    expect(task.isDone, isFalse);
    expect(task.completedAt, isNull);
  });

  test('排序：未完成在前，其次优先级，再按创建时间', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    final day = DateTime(2026, 10, 22);
    final whiteId = await repo.insert(title: '白', day: day, priority: 'white');
    await repo.insert(title: '蓝', day: day, priority: 'blue');
    await repo.insert(title: '红-后', day: day, priority: 'red');
    // 一条已完成的红，应该排到最后
    final doneRed = await repo.insert(title: '红-已完成', day: day, priority: 'red');
    await repo.setDone(doneRed, true);
    expect(whiteId, greaterThan(0));

    final titles = (await repo.tasksOn(day)).map((t) => t.title).toList();
    expect(titles, <String>['红-后', '蓝', '白', '红-已完成']);
  });

  test('删除是移入回收站：任务表没了，回收站留一份', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    final day = DateTime(2026, 10, 22);
    final id = await repo.insert(title: '要被删的', day: day, estimatedMinutes: 45);

    await repo.moveToRecycle(id);

    expect(await repo.tasksOn(day), isEmpty);

    final rows = await db.query(V6Table.recycledTasks);
    expect(rows, hasLength(1));
    expect(rows.single[RecycledTaskCol.title], '要被删的');
    expect(rows.single[RecycledTaskCol.taskId], id);
    expect(rows.single[RecycledTaskCol.estimatedMinutes], 45);
    expect(rows.single[RecycledTaskCol.deletedAt], isNotNull);
  });

  test('dailyCounts 按日期分组', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    final d1 = DateTime(2026, 10, 22);
    final d2 = DateTime(2026, 10, 23);
    await repo.insert(title: 'a', day: d1);
    await repo.insert(title: 'b', day: d1);
    await repo.insert(title: 'c', day: d2);

    final counts = await repo.dailyCounts(d1, d2);
    expect(counts[TaskDate.parseDay('2026-10-22')], 2);
    expect(counts[TaskDate.parseDay('2026-10-23')], 1);
  });

  test('演示数据只在空库时写入', () async {
    final (db, repo) = await open();
    addTearDown(db.close);

    await DemoSeed.runIfEmpty(repo);
    final first = await repo.tasksOn(DateTime.now());
    expect(first, isNotEmpty);

    // 再跑一次不该翻倍
    await DemoSeed.runIfEmpty(repo);
    expect((await repo.tasksOn(DateTime.now())).length, first.length);
  });
}
