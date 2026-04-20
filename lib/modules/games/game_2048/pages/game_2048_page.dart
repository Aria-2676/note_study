import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_2048_model.dart';
import '../providers/game_2048_provider.dart';

class Game2048Page extends StatefulWidget {
  const Game2048Page({super.key});

  @override
  State<Game2048Page> createState() => _Game2048PageState();
}

class _Game2048PageState extends State<Game2048Page> {
  late Game2048Provider _provider;
  Offset? _startPosition;
  static const double _minSwipeDistance = 30.0;

  @override
  void initState() {
    super.initState();
    _provider = Game2048Provider();
    _provider.initialize();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _handlePanStart(DragStartDetails details) {
    _startPosition = details.localPosition;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_startPosition == null) return;

    final endPosition = details.velocity.pixelsPerSecond;
    final dx = endPosition.dx;
    final dy = endPosition.dy;

    if (dx.abs() > dy.abs()) {
      if (dx > _minSwipeDistance) {
        _provider.move(MoveDirection.right);
      } else if (dx < -_minSwipeDistance) {
        _provider.move(MoveDirection.left);
      }
    } else {
      if (dy > _minSwipeDistance) {
        _provider.move(MoveDirection.down);
      } else if (dy < -_minSwipeDistance) {
        _provider.move(MoveDirection.up);
      }
    }

    _startPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('2048'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _provider.newGame(),
            ),
          ],
        ),
        body: Consumer<Game2048Provider>(
          builder: (context, provider, child) {
            if (!provider.isInitialized) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                _buildScoreBoard(provider),
                Expanded(
                  child: GestureDetector(
                    onPanStart: _handlePanStart,
                    onPanEnd: _handlePanEnd,
                    behavior: HitTestBehavior.opaque,
                    child: _buildGameBoard(provider),
                  ),
                ),
                _buildInstructions(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildScoreBoard(Game2048Provider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildScoreCard('分数', provider.score, Colors.orange),
          _buildScoreCard('最高', provider.bestScore, Colors.blue),
        ],
      ),
    );
  }

  Widget _buildScoreCard(String label, int score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 24,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameBoard(Game2048Provider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth - 32
            : constraints.maxHeight - 32;
        const double gap = 4;
        const double padding = 6;
        final cellSize = (size - padding * 2 - gap * 3) / 4;

        return Center(
          child: Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                _buildGridBackground(cellSize, gap),
                _buildGridTiles(provider, cellSize, gap, padding),
                if (provider.gameOver || provider.won)
                  _buildGameOverlay(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridBackground(double cellSize, double gap) {
    return SizedBox.expand(
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: gap,
        crossAxisSpacing: gap,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: List.generate(16, (_) {
          return Container(
            width: cellSize,
            height: cellSize,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGridTiles(Game2048Provider provider, double cellSize, double gap, double padding) {
    final tiles = <Widget>[];

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        final value = provider.game.grid[i][j];
        if (value != 0) {
          tiles.add(
            Positioned(
              left: j * (cellSize + gap),
              top: i * (cellSize + gap),
              width: cellSize,
              height: cellSize,
              child: _buildTile(value, cellSize),
            ),
          );
        }
      }
    }

    return Stack(children: tiles);
  }

  Widget _buildTile(int value, double size) {
    final color = _getTileColor(value);
    final fontSize = value >= 1000 ? size * 0.25 : size * 0.35;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: value <= 4 ? Colors.grey.shade700 : Colors.white,
        ),
      ),
    );
  }

  Color _getTileColor(int value) {
    final colors = {
      2: const Color(0xFFEEE4DA),
      4: const Color(0xFFEDE0C8),
      8: const Color(0xFFF2B179),
      16: const Color(0xFFF59563),
      32: const Color(0xFFF67C5F),
      64: const Color(0xFFF65E3B),
      128: const Color(0xFFEDCF72),
      256: const Color(0xFFEDCC61),
      512: const Color(0xFFEDC850),
      1024: const Color(0xFFEDC53F),
      2048: const Color(0xFFEDC22E),
    };
    return colors[value] ?? const Color(0xFF3C3A32);
  }

  Widget _buildGameOverlay(Game2048Provider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              provider.won ? '恭喜获胜!' : '游戏结束',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '得分: ${provider.score}',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.won)
                  TextButton(
                    onPressed: () => provider.continueGame(),
                    child: const Text('继续游戏'),
                  ),
                ElevatedButton(
                  onPressed: () => provider.newGame(),
                  child: const Text('重新开始'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            '滑动屏幕移动方块',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDirectionButton(MoveDirection.up, Icons.arrow_upward),
              const SizedBox(width: 8),
              _buildDirectionButton(MoveDirection.left, Icons.arrow_back),
              const SizedBox(width: 8),
              _buildDirectionButton(MoveDirection.down, Icons.arrow_downward),
              const SizedBox(width: 8),
              _buildDirectionButton(MoveDirection.right, Icons.arrow_forward),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton(MoveDirection direction, IconData icon) {
    return InkWell(
      onTap: () => _provider.move(direction),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade600),
      ),
    );
  }
}
