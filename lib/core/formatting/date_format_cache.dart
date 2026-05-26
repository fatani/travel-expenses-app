import 'package:intl/intl.dart';

/// Lightweight cache for [DateFormat] instances used in list hot paths.
class DateFormatCache {
  const DateFormatCache._();

  static final Map<String, DateFormat> _cache = <String, DateFormat>{};

  static DateFormat get(String pattern, String localeName) {
    final key = '$pattern\x00$localeName';
    return _cache.putIfAbsent(
      key,
      () => DateFormat(pattern, localeName),
    );
  }
}
