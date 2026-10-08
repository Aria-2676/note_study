import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/games/models/game_manifest_model.dart';
import 'package:v5_app/modules/games/models/installed_game_model.dart';

Map<String, Object?> _validGameJson([Map<String, Object?> overrides = const {}]) {
  return {
    'id': '2048',
    'name': '2048',
    'description': '经典数字合成游戏',
    'icon': 'grid_on',
    'color': '#FF9800',
    'cost': 10,
    'latestVersion': '1.0.0',
    'entry': 'index.html',
    'package': {
      'path': 'game_center/packages/game_2048_v1.0.0.zip',
      'sha256': 'ABC123',
      'sizeBytes': 4025,
    },
    ...overrides,
  };
}

void main() {
  // 校验仓库中的真实清单：条目字段非法会被解析器**静默跳过**，
  // 表现为「游戏中心里看不到这个游戏」，因此这里逐条断言。
  group('game_center/manifest.json 完整性', () {
    late Map<String, dynamic> raw;
    late GameManifest manifest;

    setUpAll(() {
      final file = File('game_center/manifest.json');
      expect(file.existsSync(), isTrue, reason: '仓库中应存在游戏清单');
      raw = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      manifest = GameManifest.fromJson(raw);
    });

    test('每个游戏条目都能被解析（没有被静默跳过）', () {
      final rawGames = (raw['games'] as List).cast<Map<String, dynamic>>();
      expect(manifest.games, hasLength(rawGames.length));
      expect(manifest.games, isNotEmpty);
    });

    test('字段与包信息完整，且包文件真实存在', () {
      for (final game in manifest.games) {
        expect(game.id, isNotEmpty);
        expect(game.name, isNotEmpty);
        expect(game.cost, greaterThan(0), reason: '${game.id} 缺少正数单价');
        expect(game.entry, isNotEmpty);
        expect(
          game.package.sha256,
          hasLength(64),
          reason: '${game.id} 未打包：sha256 未回填',
        );
        expect(
          game.package.sizeBytes,
          greaterThan(0),
          reason: '${game.id} 未打包：体积为 0',
        );
        expect(
          File(game.package.path).existsSync(),
          isTrue,
          reason: '${game.id} 的包文件不存在',
        );
      }
    });

    test('游戏 id 不重复', () {
      final ids = manifest.games.map((game) => game.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('每个游戏都实现了桥接契约', () {
      for (final item in (raw['games'] as List).cast<Map<String, dynamic>>()) {
        final id = item['id'];
        final source = item['source'] as String;
        final html = File('$source/index.html').readAsStringSync();
        final compact = html.replaceAll(RegExp(r'\s+'), ' ');

        expect(
          compact,
          contains('GameBridge.postMessage'),
          reason: '$id 未实现与容器的 postMessage 通道',
        );
        expect(
          compact,
          contains("type: 'ready'"),
          reason: '$id 未在启动时发送 ready',
        );
        expect(
          compact,
          contains('window.__native'),
          reason: '$id 未实现 __native.onMessage（拿不到最高分）',
        );
        expect(
          compact,
          contains("type: 'reportScore'"),
          reason: '$id 未上报分数',
        );
        expect(
          compact,
          contains("type: 'exit'"),
          reason: '$id 未实现退出按钮',
        );
        expect(
          compact,
          contains("type: 'gameOver'"),
          reason: '$id 未在回合结束时通知容器（无法统一结算）',
        );
        expect(
          compact,
          contains("message.type === 'restart'"),
          reason: '$id 未响应容器的「再来一局」',
        );
      }
    });
  });

  group('GameManifest', () {
    test('should parse a valid manifest', () {
      final manifest = GameManifest.fromJson({
        'schemaVersion': 1,
        'updatedAt': '2026-10-08T00:00:00Z',
        'games': [_validGameJson()],
      });

      expect(manifest.schemaVersion, 1);
      expect(manifest.updatedAt, isNotNull);
      expect(manifest.games, hasLength(1));
      expect(manifest.games.first.id, '2048');
      expect(manifest.games.first.cost, 10);
      expect(manifest.games.first.package.sha256, 'abc123');
    });

    test('should default schemaVersion to 1 when absent', () {
      final manifest = GameManifest.fromJson({
        'games': [_validGameJson()],
      });
      expect(manifest.schemaVersion, 1);
      expect(manifest.updatedAt, isNull);
    });

    test('should skip invalid game entries instead of failing whole manifest', () {
      final manifest = GameManifest.fromJson({
        'games': [
          _validGameJson(),
          _validGameJson({'id': 'broken', 'entry': '../escape.html'}),
          _validGameJson({'id': 'absolute', 'entry': '/etc/passwd'}),
          _validGameJson({'id': 'no-entry', 'entry': null}),
          _validGameJson({'id': 'no-package', 'package': null}),
          'not-an-object',
        ],
      });

      expect(manifest.games, hasLength(1));
      expect(manifest.games.first.id, '2048');
    });

    test('should throw when root is not an object', () {
      expect(() => GameManifest.fromJson('nope'), throwsFormatException);
      expect(() => GameManifest.fromJson([1, 2, 3]), throwsFormatException);
    });

    test('should throw when games array is missing', () {
      expect(() => GameManifest.fromJson({'schemaVersion': 1}), throwsFormatException);
    });

    test('should apply defaults for optional presentation fields', () {
      final manifest = GameManifest.fromJson({
        'games': [
          _validGameJson({
            'description': null,
            'icon': null,
            'color': null,
            'cost': null,
          }),
        ],
      });

      final game = manifest.games.first;
      expect(game.description, '');
      expect(game.icon, 'extension');
      expect(game.color, '#9C27B0');
      expect(game.cost, 0);
    });

    test('should ignore negative cost', () {
      final manifest = GameManifest.fromJson({
        'games': [_validGameJson({'cost': -5})],
      });
      expect(manifest.games.first.cost, 0);
    });

    test('should find a game by id', () {
      final manifest = GameManifest.fromJson({
        'games': [_validGameJson()],
      });
      expect(manifest.gameById('2048')?.name, '2048');
      expect(manifest.gameById('missing'), isNull);
    });

    test('should reject version without digits', () {
      final manifest = GameManifest.fromJson({
        'games': [_validGameJson({'latestVersion': 'beta'})],
      });
      expect(manifest.games, isEmpty);
    });
  });

  group('GamePathUtils.normalizeRelative', () {
    test('should keep safe relative paths', () {
      expect(GamePathUtils.normalizeRelative('index.html'), 'index.html');
      expect(GamePathUtils.normalizeRelative('js/main.js'), 'js/main.js');
    });

    test('should normalize backslashes', () {
      expect(GamePathUtils.normalizeRelative(r'js\main.js'), 'js/main.js');
    });

    test('should reject unsafe paths', () {
      expect(GamePathUtils.normalizeRelative('../evil'), isNull);
      expect(GamePathUtils.normalizeRelative('/etc/passwd'), isNull);
      expect(GamePathUtils.normalizeRelative(r'C:\Windows'), isNull);
      expect(GamePathUtils.normalizeRelative('a/../../b'), isNull);
      expect(GamePathUtils.normalizeRelative(''), isNull);
      expect(GamePathUtils.normalizeRelative(null), isNull);
    });
  });

  group('InstalledGamesIndex', () {
    test('should round-trip through JSON', () {
      final index = InstalledGamesIndex.empty.put(
        InstalledGame(
          gameId: '2048',
          installedVersion: '1.0.0',
          installedAt: DateTime(2026, 10, 8),
          sizeBytes: 4025,
          entry: 'index.html',
        ),
      );

      final restored = InstalledGamesIndex.fromJson(index.toJson());
      expect(restored.byId('2048')?.installedVersion, '1.0.0');
      expect(restored.byId('2048')?.sizeBytes, 4025);
    });

    test('should remove entries without mutating the original', () {
      final index = InstalledGamesIndex.empty.put(
        InstalledGame(
          gameId: '2048',
          installedVersion: '1.0.0',
          installedAt: DateTime(2026, 10, 8),
          sizeBytes: 1,
          entry: 'index.html',
        ),
      );

      final removed = index.remove('2048');
      expect(removed.byId('2048'), isNull);
      expect(index.byId('2048'), isNotNull);
    });

    test('should throw on malformed index JSON', () {
      expect(() => InstalledGamesIndex.fromJson('x'), throwsFormatException);
      expect(() => InstalledGamesIndex.fromJson({}), throwsFormatException);
    });

    test('should skip malformed entries', () {
      final index = InstalledGamesIndex.fromJson({
        'schemaVersion': 1,
        'games': {
          '2048': {
            'installedVersion': '1.0.0',
            'entry': 'index.html',
            'installedAt': '2026-10-08T00:00:00.000',
            'sizeBytes': 10,
          },
          'broken': {'installedVersion': null},
        },
      });
      expect(index.games, hasLength(1));
      expect(index.byId('2048')?.entry, 'index.html');
    });
  });
}