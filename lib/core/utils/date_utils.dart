import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static DateTime parseDate(String dateStr) {
    return DateFormat('yyyy-MM-dd').parse(dateStr);
  }

  static DateTime parseDateTime(String dateTimeStr) {
    return DateTime.parse(dateTimeStr);
  }

  static String formatDisplayDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));
    
    final dateToCompare = DateTime(date.year, date.month, date.day);
    
    if (dateToCompare == today) {
      return '今天';
    } else if (dateToCompare == yesterday) {
      return '昨天';
    } else if (dateToCompare == tomorrow) {
      return '明天';
    } else {
      return DateFormat('MM月dd日').format(date);
    }
  }

  static String formatWeekDay(DateTime date) {
    const weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekDays[date.weekday - 1];
  }

  static DateTime getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static DateTime getStartOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static DateTime getEndOfWeek(DateTime date) {
    return date.add(Duration(days: 7 - date.weekday));
  }

  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime getEndOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  static int daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inDays;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isDateBefore(DateTime a, DateTime b) {
    final dateA = DateTime(a.year, a.month, a.day);
    final dateB = DateTime(b.year, b.month, b.day);
    return dateA.isBefore(dateB);
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static List<DateTime> getDaysInMonth(int year, int month) {
    final days = <DateTime>[];
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    
    for (var i = 0; i < lastDay.day; i++) {
      days.add(firstDay.add(Duration(days: i)));
    }
    
    return days;
  }

  static List<DateTime> getDaysInWeek(DateTime date) {
    final days = <DateTime>[];
    final startOfWeek = getStartOfWeek(date);
    
    for (var i = 0; i < 7; i++) {
      days.add(startOfWeek.add(Duration(days: i)));
    }
    
    return days;
  }
}