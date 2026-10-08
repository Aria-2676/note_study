import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/points_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../../providers/scratch_provider.dart';
import '../../adapters/scratch_statistic_adapter.dart';
import '../../models/scratch_state.dart';
import 'scratch_card_logic_mixin.dart';

/// 刮奖手势、刮开进度计算与揭晓逻辑。
///
/// 从 `scratch_card_page.dart` 抽出（规范 6：单个 Widget ≤300 行）。
/// 与 [ScratchCardLogicMixin] 一样作为独立 library，只依赖 `State` 的公开能力
/// （`setState` / `context` / `mounted`）以及 LogicMixin 的公开方法，
/// 因此对外暴露的成员均为公开命名。
mixin ScratchCardGestureMixin<T extends StatefulWidget>
    on State<T>, ScratchCardLogicMixin<T> {
  /// 刮开区域的 key，用于坐标换算与命中判定。
  final GlobalKey scratchKey = GlobalKey();

  /// 已刮开的轨迹点（局部坐标）。
  final List<Offset> scratchPoints = [];

  Offset? _lastPosition;

  /// 是否显示居中的刮奖浮层。
  bool showCenteredOverlay = false;

  final ScratchStatisticAdapter _statisticAdapter = ScratchStatisticAdapter();

  static const int _gridSize = 30;
  static const double _revealThreshold = 0.4;
  static const double _scratchRadius = 20;
  static const double _minSwipeDistance = 3.0;

  void startScratching() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (scratchProvider.currentTicket == null) return;
    setState(() {
      scratchPoints.clear();
      _lastPosition = null;
      showCenteredOverlay = true;
    });
    scratchProvider.startScratching();
    _statisticAdapter.reportStartScratch();
    HapticFeedback.mediumImpact();
  }

  void exitScratching() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    scratchPoints.clear();
    _lastPosition = null;
    scratchProvider.exitScratching();
    setState(() {
      showCenteredOverlay = false;
    });
  }

  void handleScratchStart(DragStartDetails details) {
    _handleScratchPosition(details.globalPosition);
  }

  void handleScratch(DragUpdateDetails details) {
    _handleScratchPosition(details.globalPosition);
  }

  void handleScratchEnd(DragEndDetails details) {
    _lastPosition = null;
  }

  void _handleScratchPosition(Offset globalPosition) {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    final box = scratchKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.globalToLocal(globalPosition);

    if (position.dx < 0 ||
        position.dx > box.size.width ||
        position.dy < 0 ||
        position.dy > box.size.height) {
      return;
    }

    if (_lastPosition != null) {
      final distance = (position - _lastPosition!).distance;
      if (distance < _minSwipeDistance) return;
    }

    setState(() {
      scratchPoints.add(position);
      _lastPosition = position;
    });

    _checkReveal();
  }

  double _calculateScratchedPercentage() {
    if (scratchPoints.isEmpty) return 0.0;

    final box = scratchKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0.0;

    final size = box.size;
    final cellWidth = size.width / _gridSize;
    final cellHeight = size.height / _gridSize;

    final grid = List.generate(
      _gridSize,
      (_) => List.generate(_gridSize, (_) => false),
    );

    final radiusCells = (_scratchRadius / cellWidth).ceil();

    for (final point in scratchPoints) {
      final centerGridX = (point.dx / cellWidth).floor();
      final centerGridY = (point.dy / cellHeight).floor();

      for (int dx = -radiusCells; dx <= radiusCells; dx++) {
        for (int dy = -radiusCells; dy <= radiusCells; dy++) {
          final gridX = (centerGridX + dx).clamp(0, _gridSize - 1);
          final gridY = (centerGridY + dy).clamp(0, _gridSize - 1);

          final cellCenterX = (gridX + 0.5) * cellWidth;
          final cellCenterY = (gridY + 0.5) * cellHeight;
          final distance = sqrt(
            pow(point.dx - cellCenterX, 2) + pow(point.dy - cellCenterY, 2),
          );

          if (distance <= _scratchRadius) {
            grid[gridY][gridX] = true;
          }
        }
      }
    }

    int scratchedCount = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell) scratchedCount++;
      }
    }

    return scratchedCount / (_gridSize * _gridSize);
  }

  void _checkReveal() {
    final percentage = _calculateScratchedPercentage();
    if (percentage >= _revealThreshold) {
      unawaited(_revealPrize());
    }
  }

  Future<void> _revealPrize() async {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    scratchProvider.revealPrize();
    // 先落盘（同时把已揭晓票据移出彩票夹）再发奖，保证记录与发奖同序。
    await scratchProvider.saveLotteryResult();
    if (!mounted) return;
    await _claimPrize();
    if (!mounted) return;
    // 结算完成后收起浮层并清空当前票据；否则 currentTicket 一直非空，
    // 主按钮会永远停在「已选择彩票…」且被禁用，导致只能购买一次。
    exitScratching();
    scratchProvider.resetScratchCard();
  }

  void quickReveal() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    unawaited(_revealPrize());
  }

  Future<void> _claimPrize() async {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    await claimPrize(
      context: context,
      scratchProvider: scratchProvider,
      pointsProvider: pointsProvider,
      shopProvider: shopProvider,
    );
  }
}
