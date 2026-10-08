import 'dart:math';

import 'scratch_model.dart';

/// 刮刮卡「我的号码」区的一个格子：号码 + 对应奖金。
class ScratchCardCell {
  /// 号码。
  final int number;

  /// 该号码对应的奖金（积分）。未命中的格子同样标注金额，仅作展示。
  final int amount;

  const ScratchCardCell({required this.number, required this.amount});

  /// 是否与中奖号码相同。
  bool matches(int winningNumber) => number == winningNumber;
}

/// 刮刮卡卡面（双区号码玩法）。
///
/// 玩法与真实即开型彩票一致：先看「中奖号码」，再看「我的号码」，
/// 若有号码与中奖号码相同，即中得该号码对应的奖金。
class ScratchCardFace {
  /// 「中奖号码」区的号码。
  final int winningNumber;

  /// 「我的号码」区的格子。
  final List<ScratchCardCell> cells;

  const ScratchCardFace({required this.winningNumber, required this.cells});

  /// 命中的格子；未中奖（空奖）时为 null。
  ScratchCardCell? get matchedCell {
    for (final cell in cells) {
      if (cell.matches(winningNumber)) return cell;
    }
    return null;
  }

  /// 是否中奖。
  bool get isWin => matchedCell != null;
}

/// 由已抽定的票据**确定性**生成卡面。
///
/// 抽奖结果在购票时已确定，卡面只负责「把结果翻译成一张自洽的刮刮乐」：
/// - 中奖时，「我的号码」中**恰好一个**格子等于中奖号码，其金额即票据面额；
/// - 空奖时，没有任何格子等于中奖号码。
///
/// 生成过程以票据 id 等字段为种子做确定性随机，因此同一张票反复进入得到
/// **同一张卡面**，且**无需新增数据库字段**。
class ScratchFaceGenerator {
  const ScratchFaceGenerator._();

  /// 「我的号码」格子数量（3 × 3）。
  static const int cellCount = 9;

  /// 号码取值范围 1 ~ [maxNumber]。
  static const int maxNumber = 99;

  /// 生成卡面。
  static ScratchCardFace generate(ScratchTicket ticket) {
    final random = Random(_seedOf(ticket));

    final winningNumber = 1 + random.nextInt(maxNumber);

    // 我的号码：互不相同，且都不等于中奖号码，保证命中与否只由下面决定。
    final numbers = <int>{};
    while (numbers.length < cellCount) {
      final number = 1 + random.nextInt(maxNumber);
      if (number == winningNumber) continue;
      numbers.add(number);
    }
    final numberList = numbers.toList();

    // 中奖时随机挑一个格子作为命中格（空奖时不设命中格）。
    final isWin = ticket.prizeValue > 0 && ticket.prizeType != 'none';
    final winningIndex = isWin ? random.nextInt(cellCount) : -1;

    final distractors = _distractorAmounts(ticket.costPoints);
    final cells = <ScratchCardCell>[];
    for (var i = 0; i < cellCount; i++) {
      final isMatchCell = i == winningIndex;
      cells.add(
        ScratchCardCell(
          number: isMatchCell ? winningNumber : numberList[i],
          amount: isMatchCell
              ? ticket.prizeValue
              : distractors[random.nextInt(distractors.length)],
        ),
      );
    }

    return ScratchCardFace(winningNumber: winningNumber, cells: cells);
  }

  /// 干扰金额：取自常见的几档，看起来真实但与结果无关。
  static List<int> _distractorAmounts(int cost) {
    final base = cost > 0 ? cost : 10;
    return [base, base * 2, base * 3, base * 5, base * 10];
  }

  /// 仅使用数值字段做种子，保证跨运行稳定（不依赖字符串 hashCode）。
  static int _seedOf(ScratchTicket ticket) {
    final id = ticket.id ?? 0;
    final mixed = id * 2654435761 + ticket.prizeValue * 97 + ticket.costPoints * 13;
    return mixed & 0x7fffffff;
  }
}