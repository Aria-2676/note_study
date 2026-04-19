import 'package:flutter/material.dart';
import '../../models/scratch_model.dart';

class ScratchCardWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        key: scratchKey,
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
            if (ticket != null)
              _PrizeContentWidget(ticket: ticket!, isDark: isDark),
            if (!isRevealed && ticket != null)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: isScratching ? onPanStart : null,
                  onPanUpdate: isScratching ? onPanUpdate : null,
                  onPanEnd: isScratching ? onPanEnd : null,
                  child: ClipPath(
                    clipper: ScratchClipper(scratchPoints),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  colorScheme.surfaceContainerHigh,
                                  colorScheme.surfaceContainerHighest,
                                ]
                              : [
                                  colorScheme.surfaceContainerHigh,
                                  colorScheme.surfaceContainerHighest,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 48,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isScratching ? '刮开这里' : '准备刮奖',
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

class ScratchClipper extends CustomClipper<Path> {
  final List<Offset> points;
  final double radius;

  ScratchClipper(this.points, [this.radius = 20]);

  @override
  Path getClip(Size size) {
    final rectPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (points.isEmpty) {
      return rectPath;
    }

    final scratchPath = Path();
    for (final point in points) {
      scratchPath.addOval(Rect.fromCircle(center: point, radius: radius));
    }

    return Path.combine(PathOperation.difference, rectPath, scratchPath);
  }

  @override
  bool shouldReclip(covariant ScratchClipper oldClipper) {
    return points.length != oldClipper.points.length;
  }
}
