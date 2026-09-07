import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/utils/date_utils.dart';

void main() {
  group('DateUtils', () {
    test('isSameDay should return true for same date', () {
      final date1 = DateTime(2024, 1, 15, 10, 30);
      final date2 = DateTime(2024, 1, 15, 18, 45);
      expect(DateUtils.isSameDay(date1, date2), isTrue);
    });

    test('isSameDay should return false for different dates', () {
      final date1 = DateTime(2024, 1, 15);
      final date2 = DateTime(2024, 1, 16);
      expect(DateUtils.isSameDay(date1, date2), isFalse);
    });

    test('isDateBefore should return true when first date is before second', () {
      final date1 = DateTime(2024, 1, 15);
      final date2 = DateTime(2024, 1, 16);
      expect(DateUtils.isDateBefore(date1, date2), isTrue);
    });

    test('isDateBefore should return false when dates are equal', () {
      final date1 = DateTime(2024, 1, 15);
      final date2 = DateTime(2024, 1, 15);
      expect(DateUtils.isDateBefore(date1, date2), isFalse);
    });

    test('isDateBefore should return false when first date is after second', () {
      final date1 = DateTime(2024, 1, 16);
      final date2 = DateTime(2024, 1, 15);
      expect(DateUtils.isDateBefore(date1, date2), isFalse);
    });

    test('formatDate should return correct format', () {
      final date = DateTime(2024, 12, 25);
      expect(DateUtils.formatDate(date), '2024-12-25');
    });

    test('daysBetween should return correct number of days', () {
      final from = DateTime(2024, 1, 1);
      final to = DateTime(2024, 1, 10);
      expect(DateUtils.daysBetween(from, to), 9);
    });

    test('isToday should return true for today', () {
      final today = DateTime.now();
      expect(DateUtils.isToday(today), isTrue);
    });

    test('formatDisplayDate should return "今天" for today', () {
      final today = DateTime.now();
      expect(DateUtils.formatDisplayDate(today), '今天');
    });

    test('getDaysInMonth should return correct number of days', () {
      final days = DateUtils.getDaysInMonth(2024, 2);
      expect(days.length, 29);
    });
  });
}