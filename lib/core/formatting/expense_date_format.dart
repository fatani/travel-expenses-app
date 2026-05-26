import 'date_format_cache.dart';

/// Compact expense dates for card surfaces.
class ExpenseDateFormat {
  const ExpenseDateFormat._();

  static String cardDate(DateTime spentAt, String localeTag, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final local = spentAt.toLocal();
    final pattern =
        local.year == reference.year ? 'd MMM' : 'd MMM yyyy';
    return DateFormatCache.get(pattern, localeTag).format(local);
  }

  static String cardTime(DateTime spentAt, String localeTag, {bool isArabic = false}) {
    if (spentAt.hour == 0 && spentAt.minute == 0) {
      return '';
    }
    final pattern = isArabic ? 'h:mm a' : 'HH:mm';
    return DateFormatCache.get(pattern, localeTag).format(spentAt.toLocal());
  }
}
