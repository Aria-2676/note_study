class NumUtils {
  static bool isEven(int num) {
    return num % 2 == 0;
  }

  static bool isOdd(int num) {
    return num % 2 != 0;
  }

  static int clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int max(int a, int b) {
    return a > b ? a : b;
  }

  static int min(int a, int b) {
    return a < b ? a : b;
  }

  static double maxDouble(double a, double b) {
    return a > b ? a : b;
  }

  static double minDouble(double a, double b) {
    return a < b ? a : b;
  }

  static int abs(int num) {
    return num.abs();
  }

  static double absDouble(double num) {
    return num.abs();
  }

  static int round(double num) {
    return num.round();
  }

  static int floor(double num) {
    return num.floor();
  }

  static int ceil(double num) {
    return num.ceil();
  }

  static String formatNumber(int num) {
    if (num >= 1000000) {
      return '${(num / 10000).toStringAsFixed(1)}万';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)}k';
    }
    return num.toString();
  }

  static String formatCurrency(double amount, {String symbol = '¥'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  static bool isPositive(int num) {
    return num > 0;
  }

  static bool isNegative(int num) {
    return num < 0;
  }

  static int sign(int num) {
    if (num > 0) return 1;
    if (num < 0) return -1;
    return 0;
  }

  static int gcd(int a, int b) {
    while (b != 0) {
      final temp = b;
      b = a % b;
      a = temp;
    }
    return a;
  }

  static int lcm(int a, int b) {
    return a * b ~/ gcd(a, b);
  }

  static double percentage(int part, int total) {
    if (total == 0) return 0;
    return (part / total) * 100;
  }

  static int randomInt(int min, int max) {
    return min + (DateTime.now().millisecondsSinceEpoch % (max - min + 1));
  }
}