class SafeParser {
  static double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static String toStr(dynamic value, {String fallback = ""}) {
    if (value == null) return fallback;
    return value.toString();
  }
}
