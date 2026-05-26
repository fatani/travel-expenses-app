/// Defensive helpers for reading persisted rows without crashing the app.
abstract final class DefensiveParse {
  static String? readTrimmedString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? readPositiveDouble(Object? value) {
    if (value is! num) {
      return null;
    }
    final parsed = value.toDouble();
    if (parsed.isNaN || parsed.isInfinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static double? readNonNegativeDouble(Object? value) {
    if (value is! num) {
      return null;
    }
    final parsed = value.toDouble();
    if (parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return null;
    }
    return parsed;
  }

  static DateTime? readDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  static bool readBool(Object? value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() != 0;
    }
    return fallback;
  }
}
