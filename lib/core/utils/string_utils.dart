class StringUtils {
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }

  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }

  static String trim(String str) {
    return str.trim();
  }

  static String truncate(String str, int maxLength, {String suffix = '...'}) {
    if (str.length <= maxLength) {
      return str;
    }
    return str.substring(0, maxLength - suffix.length) + suffix;
  }

  static bool equalsIgnoreCase(String a, String b) {
    return a.toLowerCase() == b.toLowerCase();
  }

  static String capitalize(String str) {
    if (isEmpty(str)) {
      return str;
    }
    return str[0].toUpperCase() + str.substring(1);
  }

  static String camelCaseToSnakeCase(String str) {
    return str.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)}_${match.group(2)}',
    ).toLowerCase();
  }

  static String snakeCaseToCamelCase(String str) {
    final parts = str.split('_');
    return parts.map((part) => capitalize(part)).join();
  }

  static String removeWhitespace(String str) {
    return str.replaceAll(RegExp(r'\s+'), '');
  }

  static bool isValidEmail(String str) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(str);
  }

  static bool isValidPhone(String str) {
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegex.hasMatch(str.replaceAll(RegExp(r'\s+'), ''));
  }

  static String padLeft(String str, int length, [String pad = ' ']) {
    return str.padLeft(length, pad);
  }

  static String padRight(String str, int length, [String pad = ' ']) {
    return str.padRight(length, pad);
  }

  static String repeat(String str, int times) {
    return str * times;
  }

  static String reverse(String str) {
    return str.split('').reversed.join();
  }

  static List<String> splitByLength(String str, int length) {
    final chunks = <String>[];
    for (var i = 0; i < str.length; i += length) {
      chunks.add(str.substring(i, i + length > str.length ? str.length : i + length));
    }
    return chunks;
  }
}