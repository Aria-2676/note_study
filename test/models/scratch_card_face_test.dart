import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/scratch/models/scratch_card_face.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';

/// 双区号码卡面的生成规则验证。
void main() {
  ScratchTicket ticket({
    int id = 1,
    int cost = 10,
    String type = 'integral',
    int value = 30,
  }) => ScratchTicket(
    id: id,
    costPoints: cost,
    prizeId: 'seed',
    prizeName: value > 0 ? '$value积分' : '谢谢参与',
    prizeType: type,
    prizeValue: value,
  );

  String faceSignature(ScratchCardFace face) =>
      '${face.winningNumber}|${face.cells.map((c) => '${c.number}:${c.amount}').join(',')}';

  group('ScratchFaceGenerator', () {
    test('同一张票生成完全相同的卡面（确定性）', () {
      expect(
        faceSignature(ScratchFaceGenerator.generate(ticket())),
        faceSignature(ScratchFaceGenerator.generate(ticket())),
      );
    });

    test('中奖时恰好一个格子号码命中，其余号码互不相同', () {
      final face = ScratchFaceGenerator.generate(ticket(value: 30));

      expect(face.cells, hasLength(ScratchFaceGenerator.cellCount));
      final numbers = face.cells.map((c) => c.number).toList();
      expect(numbers.where((n) => n == face.winningNumber), hasLength(1));
      // 非命中格之间互不相同，且都不等于中奖号码
      final nonMatch = numbers.where((n) => n != face.winningNumber).toList();
      expect(nonMatch.toSet(), hasLength(nonMatch.length));
    });

    test('命中格的金额即抽定奖项面额', () {
      final face = ScratchFaceGenerator.generate(ticket(value: 30));

      expect(face.isWin, isTrue);
      expect(face.matchedCell, isNotNull);
      expect(face.matchedCell!.amount, 30);
    });

    test('空奖时没有任何号码命中', () {
      final face = ScratchFaceGenerator.generate(
        ticket(type: 'none', value: 0),
      );

      expect(face.isWin, isFalse);
      expect(face.matchedCell, isNull);
      expect(face.cells.where((c) => c.number == face.winningNumber), isEmpty);
    });

    test('号码落在 1~99，金额均为正', () {
      final face = ScratchFaceGenerator.generate(ticket());

      expect(
        face.winningNumber,
        inInclusiveRange(1, ScratchFaceGenerator.maxNumber),
      );
      for (final cell in face.cells) {
        expect(
          cell.number,
          inInclusiveRange(1, ScratchFaceGenerator.maxNumber),
        );
        expect(cell.amount, greaterThan(0));
      }
    });

    test('不同票据得到不同卡面', () {
      final a = faceSignature(ScratchFaceGenerator.generate(ticket(id: 1)));
      final b = faceSignature(ScratchFaceGenerator.generate(ticket(id: 2)));

      expect(a, isNot(b));
    });
  });
}