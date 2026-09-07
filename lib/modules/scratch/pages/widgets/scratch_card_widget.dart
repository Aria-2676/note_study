import 'package:flutter/material.dart';
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
        height: 200,
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
              _PrizeContentWidget(ticket: widget.ticket!, isDark: isDark),
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
  }

  @override
  bool shouldRepaint(covariant ScratchLayerPainter oldDelegate) {
    return scratchPoints.length != oldDelegate.scratchPoints.length;
  }
}

class _PrizeContentWidget extends StatelessWidget {
  final ScratchTicket ticket;
  final bool isDark;

  const _PrizeContentWidget({required this.ticket, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isDark
        ? colorScheme.primaryContainer.withValues(alpha: 0.3)
        : const Color(0xFFE8F5E9);
    final textColor = isDark ? colorScheme.onSurface : const Color(0xFF1B5E20);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ticket.prizeType == 'integral' ? Icons.star : Icons.card_giftcard,
            size: 64,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          Text(
            ticket.prizeName,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.prizeType == 'integral' ? '积分奖励' : '商品奖励',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
