import 'dart:math';

enum MoveDirection { up, down, left, right }

class Game2048Model {
  final List<List<int>> grid;
  final int score;
  final int bestScore;
  final bool gameOver;
  final bool won;

  const Game2048Model({
    required this.grid,
    this.score = 0,
    this.bestScore = 0,
    this.gameOver = false,
    this.won = false,
  });

  factory Game2048Model.initial({int bestScore = 0}) {
    final grid = List.generate(4, (_) => List.filled(4, 0));
    final model = Game2048Model(grid: grid, bestScore: bestScore);
    return model._addRandomTile()._addRandomTile();
  }

  Game2048Model copyWith({
    List<List<int>>? grid,
    int? score,
    int? bestScore,
    bool? gameOver,
    bool? won,
  }) {
    return Game2048Model(
      grid: grid ?? _copyGrid(this.grid),
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      gameOver: gameOver ?? this.gameOver,
      won: won ?? this.won,
    );
  }

  static List<List<int>> _copyGrid(List<List<int>> grid) {
    return grid.map((row) => List<int>.from(row)).toList();
  }

  Game2048Model _addRandomTile() {
    final emptyCells = <Point<int>>[];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) {
          emptyCells.add(Point(i, j));
        }
      }
    }

    if (emptyCells.isEmpty) return this;

    final random = Random();
    final cell = emptyCells[random.nextInt(emptyCells.length)];
    final newGrid = _copyGrid(grid);
    newGrid[cell.x][cell.y] = random.nextDouble() < 0.9 ? 2 : 4;

    return copyWith(grid: newGrid);
  }

  Game2048Model move(MoveDirection direction) {
    if (gameOver) return this;

    List<List<int>> newGrid = _copyGrid(grid);
    int newScore = score;
    bool moved = false;

    switch (direction) {
      case MoveDirection.left:
        for (int i = 0; i < 4; i++) {
          final result = _mergeRow(newGrid[i]);
          newGrid[i] = result.row;
          newScore += result.score;
          if (result.moved) moved = true;
        }
        break;
      case MoveDirection.right:
        for (int i = 0; i < 4; i++) {
          final result = _mergeRow(newGrid[i].reversed.toList());
          newGrid[i] = result.row.reversed.toList();
          newScore += result.score;
          if (result.moved) moved = true;
        }
        break;
      case MoveDirection.up:
        for (int j = 0; j < 4; j++) {
          final col = [newGrid[0][j], newGrid[1][j], newGrid[2][j], newGrid[3][j]];
          final result = _mergeRow(col);
          for (int i = 0; i < 4; i++) {
            newGrid[i][j] = result.row[i];
          }
          newScore += result.score;
          if (result.moved) moved = true;
        }
        break;
      case MoveDirection.down:
        for (int j = 0; j < 4; j++) {
          final col = [newGrid[3][j], newGrid[2][j], newGrid[1][j], newGrid[0][j]];
          final result = _mergeRow(col);
          for (int i = 0; i < 4; i++) {
            newGrid[3 - i][j] = result.row[i];
          }
          newScore += result.score;
          if (result.moved) moved = true;
        }
        break;
    }

    if (!moved) return this;

    final newBestScore = newScore > bestScore ? newScore : bestScore;
    var newState = copyWith(
      grid: newGrid,
      score: newScore,
      bestScore: newBestScore,
    );

    newState = newState._addRandomTile();

    final isWon = newState._checkWin();
    final isGameOver = !isWon && newState._checkGameOver();

    return newState.copyWith(won: isWon, gameOver: isGameOver);
  }

  _MergeResult _mergeRow(List<int> row) {
    final original = List<int>.from(row);
    final filtered = row.where((v) => v != 0).toList();
    final merged = <int>[];
    int score = 0;
    int i = 0;

    while (i < filtered.length) {
      if (i + 1 < filtered.length && filtered[i] == filtered[i + 1]) {
        final mergedValue = filtered[i] * 2;
        merged.add(mergedValue);
        score += mergedValue;
        i += 2;
      } else {
        merged.add(filtered[i]);
        i++;
      }
    }

    while (merged.length < 4) {
      merged.add(0);
    }

    final moved = !_listsEqual(original, merged);
    return _MergeResult(row: merged, score: score, moved: moved);
  }

  bool _listsEqual(List<int> a, List<int> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _checkWin() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 2048) return true;
      }
    }
    return false;
  }

  bool _checkGameOver() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (grid[i][j] == 0) return false;
        if (j < 3 && grid[i][j] == grid[i][j + 1]) return false;
        if (i < 3 && grid[i][j] == grid[i + 1][j]) return false;
      }
    }
    return true;
  }
}

class _MergeResult {
  final List<int> row;
  final int score;
  final bool moved;

  _MergeResult({required this.row, required this.score, required this.moved});
}
