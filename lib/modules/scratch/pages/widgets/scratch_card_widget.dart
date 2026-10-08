import 'package:flutter/material.dart';
import '../../models/scratch_card_face.dart';
import '../../models/scratch_model.dart';

class ScratchCardWidget extends StatefulWidget {
  final GlobalKey scratchKey;
  final ScratchTicket? ticket;
  final bool isScratching;
  final bool isRevealed;
  final List<Offset> scratchPoints;
  final void Function(DragStartDetails)? onPanStart;
  final void Function(DragUpdateDetails)? onPanUpdate;
  final void Function(DragEndDetails)? onPanEnd;

  const ScratchCardWidget({
    super.key,
    required this.scratchKey,
    required this.ticket,
    required this.isScratching,
    required this.isRevealed,
    required this.scratchPoints,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
  });

  @override
  State<ScratchCardWidget> createState() => _ScratchCardWidgetState();
}

class _ScratchCardWidgetState extends State<ScratchCardWidget> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        key: widget.scratchKey,
        width: 300,
        height: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            if (widget.ticket != null)
              _ScratchCardFaceWidget(
                ticket: widget.ticket!,
                isDark: isDark,
                isRevealed: widget.isRevealed,
              ),
            if (!widget.isRevealed && widget.ticket != null)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: widget.isScratching ? widget.onPanStart : null,
                  onPanUpdate: widget.isScratching ? widget.onPanUpdate : null,
                  onPanEnd: widget.isScratching ? widget.onPanEnd : null,
                  child: ScratchLayer(
                    scratchPoints: widget.scratchPoints,
                    isDark: isDark,
                    colorScheme: colorScheme,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ScratchLayer extends StatelessWidget {
  final List<Offset> scratchPoints;
  final bool isDark;
  final ColorScheme colorScheme;

  const ScratchLayer({
    super.key,
    required this.scratchPoints,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ScratchLayerPainter(
        scratchPoints: scratchPoints,
        isDark: isDark,
        colorScheme: colorScheme,
      ),
    );
  }
}

class ScratchLayerPainter extends CustomPainter {
  final List<Offset> scratchPoints;
  final bool isDark;
  final ColorScheme colorScheme;

  ScratchLayerPainter({
    required this.scratchPoints,
    required this.isDark,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 必须先把遮罩绘制到**独立图层**：BlendMode.clear 会擦除「同一图层内」已绘制
    // 的内容，而遮罩与卡面同处一个 Stack 图层，不隔离就会把下层卡面一起擦掉，
    // 表现为刮开处一片透明（露出浮层黑色背景），只有整张揭晓后才看得见票面。
    canvas.saveLayer(Offset.zero & size, Paint());

    final maskPaint = Paint()
      ..color = isDark
          ? colorScheme.surfaceContainerHighest
          : const Color(0xFFD0D0D0)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), maskPaint);

    if (scratchPoints.isEmpty) {
      final center = Offset(size.width / 2, size.height / 2);

      final iconPainter = TextPainter(
        text: const TextSpan(text: '👆'),
        textDirection: TextDirection.ltr,
      )..layout();

      iconPainter.paint(canvas, Offset(center.dx - 24, center.dy - 24));

      final textPainter = TextPainter(
        text: TextSpan(
          text: '刮开这里',
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(center.dx - textPainter.width / 2, center.dy + 32),
      );
    }

    if (scratchPoints.isNotEmpty) {
      final path = Path();
      for (int i = 0; i < scratchPoints.length; i++) {
        if (i == 0) {
          path.moveTo(scratchPoints[i].dx, scratchPoints[i].dy);
        } else {
          path.lineTo(scratchPoints[i].dx, scratchPoints[i].dy);
        }
      }

      final pathPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..blendMode = BlendMode.clear;

      canvas.drawPath(path, pathPaint);

      for (final point in scratchPoints) {
        canvas.drawCircle(point, 20, pathPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ScratchLayerPainter oldDelegate) {
    return scratchPoints.length != oldDelegate.scratchPoints.length;
  }
}

/// 卡面内容：上「中奖号码」区、下「我的号码」区（3 × 3）。
///
/// 号码与金额由 [ScratchFaceGenerator] 依据已抽定的票据确定性生成；
/// 揭晓后命中的格子以高亮标出。
class _ScratchCardFaceWidget extends StatelessWidget {
  final ScratchTicket ticket;
  final bool isDark;
  final bool isRevealed;

  const _ScratchCardFaceWidget({
    required this.ticket,
    required this.isDark,
    required this.isRevealed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final face = ScratchFaceGenerator.generate(ticket);
    final bgColor = isDark
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : const Color(0xFFE8F5E9);
    final textColor = isDark ? colorScheme.onSurface : const Color(0xFF1B5E20);

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgColor),
      child: Column(
        children: [
          _buildLabel('中奖号码', colorScheme),
          const SizedBox(height: 6),
          _buildWinningNumber(face.winningNumber, colorScheme),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _buildLabel('我的号码', colorScheme),
          const SizedBox(height: 6),
          Expanded(child: _buildGrid(face, colorScheme, textColor)),
          const SizedBox(height: 4),
          Text(
            '号码相同即中对应奖金',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, ColorScheme colorScheme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildWinningNumber(int winningNumber, ColorScheme colorScheme) {
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$winningNumber',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildGrid(
    ScratchCardFace face,
    ColorScheme colorScheme,
    Color textColor,
  ) {
    final matched = isRevealed ? face.matchedCell : null;
    final rows = <Widget>[];
    for (var row = 0; row < 3; row++) {
      final cells = <Widget>[];
      for (var column = 0; column < 3; column++) {
        final cell = face.cells[row * 3 + column];
        final isHit = matched != null && cell.number == face.winningNumber;
        cells.add(
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: _buildCell(cell, isHit, colorScheme, textColor),
            ),
          ),
        );
      }
      rows.add(Expanded(child: Row(children: cells)));
    }
    return Column(children: rows);
  }

  Widget _buildCell(
    ScratchCardCell cell,
    bool isHit,
    ColorScheme colorScheme,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isHit
            ? Colors.amber.withValues(alpha: 0.35)
            : colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHit
              ? Colors.amber
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isHit ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${cell.number}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          Text(
            '${cell.amount}分',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isHit ? FontWeight.bold : FontWeight.normal,
              color: isHit
                  ? Colors.orange.shade800
                  : colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
