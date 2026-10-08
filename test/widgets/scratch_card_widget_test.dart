import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/scratch/pages/widgets/scratch_card_widget.dart';

/// 刮开交互的像素级验证。
///
/// 回归的是这个真实缺陷：遮罩用 `BlendMode.clear` 擦除，但遮罩与卡面同处一个
/// 图层，导致刮开处把**下面的卡面也一起擦掉**（表现为露出浮层黑底），
/// 只有整张揭晓后才看得见票面。
void main() {
  ScratchTicket ticket() => ScratchTicket(
    id: 1,
    costPoints: 10,
    prizeId: 'p1',
    prizeName: '10积分',
    prizeType: 'integral',
    prizeValue: 10,
  );

  /// 读取渲染结果中某点的 RGBA。
  Future<List<int>> pixelAt(
    GlobalKey boundaryKey,
    Offset point,
  ) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = data!.buffer.asUint8List();
    final index = ((point.dy.toInt() * image.width) + point.dx.toInt()) * 4;
    return [
      bytes[index],
      bytes[index + 1],
      bytes[index + 2],
      bytes[index + 3],
    ];
  }

  testWidgets('刮开处应露出卡面（不透明），未刮处仍被涂层覆盖', (tester) async {
    final boundaryKey = GlobalKey();
    final scratchKey = GlobalKey();
    const scratchedPoint = Offset(150, 180);
    const coveredPoint = Offset(10, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ScratchCardWidget(
              scratchKey: scratchKey,
              ticket: ticket(),
              isScratching: true,
              isRevealed: false,
              scratchPoints: const [scratchedPoint],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final scratched = await pixelAt(boundaryKey, scratchedPoint);
      final covered = await pixelAt(boundaryKey, coveredPoint);

      // 刮开处必须不透明：透明就意味着连卡面也被擦掉了（露出浮层黑底）。
      expect(
        scratched[3],
        255,
        reason: '刮开处不应是透明的，应露出卡面',
      );

      // 未刮处应仍被灰色涂层盖住。
      expect(covered[3], 255);
      expect(covered[0], closeTo(208, 12));
      expect(covered[1], closeTo(208, 12));
      expect(covered[2], closeTo(208, 12));
    });
  });
}