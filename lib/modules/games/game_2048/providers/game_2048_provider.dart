import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_2048_model.dart';

class Game2048Provider extends ChangeNotifier {
  static const String _bestScoreKey = 'game_2048_best_score';

  Game2048Model _game = const Game2048Model(grid: []);
  bool _initialized = false;

  Game2048Model get game => _game;
  int get score => _game.score;
  int get bestScore => _game.bestScore;
  bool get gameOver => _game.gameOver;
  bool get won => _game.won;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final bestScore = prefs.getInt(_bestScoreKey) ?? 0;

    _game = Game2048Model.initial(bestScore: bestScore);
    _initialized = true;
    notifyListeners();
  }

  void move(MoveDirection direction) {
    if (_game.gameOver || _game.won) return;

    _game = _game.move(direction);
    _saveBestScore();
    notifyListeners();
  }

  void newGame() {
    _game = Game2048Model.initial(bestScore: _game.bestScore);
    notifyListeners();
  }

  void continueGame() {
    _game = _game.copyWith(won: false);
    notifyListeners();
  }

  Future<void> _saveBestScore() async {
    if (_game.bestScore > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_bestScoreKey, _game.bestScore);
    }
  }
}
