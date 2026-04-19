import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/scratch/models/scratch_state.dart';

void main() {
  group('PrizeItem', () {
    test('should create PrizeItem with correct properties', () {
      final prize = PrizeItem(
        id: 'test_1',
        name: '10积分',
        type: 'integral',
        value: 10,
        weight: 1.0,
        isDefault: true,
      );

      expect(prize.id, 'test_1');
      expect(prize.name, '10积分');
      expect(prize.type, 'integral');
      expect(prize.value, 10);
      expect(prize.weight, 1.0);
      expect(prize.isDefault, true);
    });

    test('should convert to Map correctly', () {
      final prize = PrizeItem(
        id: 'test_1',
        name: '10积分',
        type: 'integral',
        value: 10,
        weight: 1.5,
        isDefault: true,
      );

      final map = prize.toMap();

      expect(map['id'], 'test_1');
      expect(map['name'], '10积分');
      expect(map['type'], 'integral');
      expect(map['value'], 10);
      expect(map['weight'], 1.5);
      expect(map['isDefault'], 1);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 'test_2',
        'name': '商品A',
        'type': 'goods',
        'value': 50,
        'weight': 0.5,
        'isDefault': 0,
      };

      final prize = PrizeItem.fromMap(map);

      expect(prize.id, 'test_2');
      expect(prize.name, '商品A');
      expect(prize.type, 'goods');
      expect(prize.value, 50);
      expect(prize.weight, 0.5);
      expect(prize.isDefault, false);
    });

    test('should copyWith correctly', () {
      final prize = PrizeItem(
        id: 'test_1',
        name: '10积分',
        type: 'integral',
        value: 10,
      );

      final copied = prize.copyWith(value: 20, weight: 2.0);

      expect(copied.id, 'test_1');
      expect(copied.name, '10积分');
      expect(copied.value, 20);
      expect(copied.weight, 2.0);
    });

    test('should compare by id for equality', () {
      final prize1 = PrizeItem(
        id: 'test_1',
        name: 'A',
        type: 'integral',
        value: 10,
      );
      final prize2 = PrizeItem(
        id: 'test_1',
        name: 'B',
        type: 'goods',
        value: 20,
      );
      final prize3 = PrizeItem(
        id: 'test_2',
        name: 'A',
        type: 'integral',
        value: 10,
      );

      expect(prize1 == prize2, true);
      expect(prize1 == prize3, false);
      expect(prize1.hashCode, prize2.hashCode);
    });
  });

  group('ScratchTicket', () {
    test('should create ScratchTicket with correct properties', () {
      final ticket = ScratchTicket(
        id: 1,
        costPoints: 10,
        prizeId: 'prize_1',
        prizeName: '50积分',
        prizeType: 'integral',
        prizeValue: 50,
        isScratched: true,
        isRevealed: true,
      );

      expect(ticket.id, 1);
      expect(ticket.costPoints, 10);
      expect(ticket.prizeId, 'prize_1');
      expect(ticket.prizeName, '50积分');
      expect(ticket.prizeType, 'integral');
      expect(ticket.prizeValue, 50);
      expect(ticket.isScratched, true);
      expect(ticket.isRevealed, true);
    });

    test('should set createdAt to current time by default', () {
      final before = DateTime.now();
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'prize_1',
        prizeName: '50积分',
        prizeType: 'integral',
        prizeValue: 50,
      );
      final after = DateTime.now();

      expect(
        ticket.createdAt.isAfter(before.subtract(const Duration(seconds: 1))),
        true,
      );
      expect(
        ticket.createdAt.isBefore(after.add(const Duration(seconds: 1))),
        true,
      );
    });

    test('should convert to Map and from Map correctly', () {
      final ticket = ScratchTicket(
        id: 1,
        costPoints: 10,
        prizeId: 'prize_1',
        prizeName: '50积分',
        prizeType: 'integral',
        prizeValue: 50,
        isScratched: true,
        isRevealed: false,
      );

      final map = ticket.toMap();
      final restored = ScratchTicket.fromMap(map);

      expect(restored.id, ticket.id);
      expect(restored.costPoints, ticket.costPoints);
      expect(restored.prizeId, ticket.prizeId);
      expect(restored.prizeName, ticket.prizeName);
      expect(restored.prizeType, ticket.prizeType);
      expect(restored.prizeValue, ticket.prizeValue);
      expect(restored.isScratched, ticket.isScratched);
      expect(restored.isRevealed, ticket.isRevealed);
    });

    test('should copyWith correctly', () {
      final ticket = ScratchTicket(
        id: 1,
        costPoints: 10,
        prizeId: 'prize_1',
        prizeName: '50积分',
        prizeType: 'integral',
        prizeValue: 50,
      );

      final copied = ticket.copyWith(isRevealed: true);

      expect(copied.id, 1);
      expect(copied.isRevealed, true);
      expect(copied.costPoints, 10);
    });
  });

  group('LotteryRecord', () {
    test('should create LotteryRecord with correct properties', () {
      final record = LotteryRecord(
        id: 1,
        drawTime: DateTime(2024, 1, 1, 12, 0),
        prizeName: '100积分',
        prizeType: 'integral',
        prizeValue: 100,
        costPoints: 10,
      );

      expect(record.id, 1);
      expect(record.drawTime, DateTime(2024, 1, 1, 12, 0));
      expect(record.prizeName, '100积分');
      expect(record.prizeType, 'integral');
      expect(record.prizeValue, 100);
      expect(record.costPoints, 10);
    });

    test('should convert to Map and from Map correctly', () {
      final record = LotteryRecord(
        id: 1,
        drawTime: DateTime(2024, 1, 1, 12, 0),
        prizeName: '100积分',
        prizeType: 'integral',
        prizeValue: 100,
        costPoints: 10,
      );

      final map = record.toMap();
      final restored = LotteryRecord.fromMap(map);

      expect(restored.id, record.id);
      expect(restored.prizeName, record.prizeName);
      expect(restored.prizeType, record.prizeType);
      expect(restored.prizeValue, record.prizeValue);
      expect(restored.costPoints, record.costPoints);
    });
  });

  group('ScratchState', () {
    test('idle state should have correct properties', () {
      const state = ScratchState.idle;

      expect(state.canStartScratch, true);
      expect(state.isScratching, false);
      expect(state.isRevealed, false);
      expect(state.canChangeCost, true);
    });

    test('scratching state should have correct properties', () {
      const state = ScratchState.scratching;

      expect(state.canStartScratch, false);
      expect(state.isScratching, true);
      expect(state.isRevealed, false);
      expect(state.canChangeCost, false);
    });

    test('revealed state should have correct properties', () {
      const state = ScratchState.revealed;

      expect(state.canStartScratch, false);
      expect(state.isScratching, false);
      expect(state.isRevealed, true);
      expect(state.canChangeCost, false);
    });
  });
}
