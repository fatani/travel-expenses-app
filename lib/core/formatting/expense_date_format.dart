import 'package:intl/intl.dart';

/// Compact expense dates for card surfaces.
class ExpenseDateFormat {
  const ExpenseDateFormat._();

  static String cardDate(DateTime spentAt, String localeTag, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final local = spentAt.toLocal();
    final pattern =
        local.year == reference.year ? 'd MMM' : 'd MMM yyyy';
    return DateFormat(pattern, localeTag).format(local);
  }

  static String cardTime(DateTime spentAt, String localeTag, {bool isArabic = false}) {
    if (spentAt.hour == 0 && spentAt.minute == 0) {
      return '';
    }
    return DateFormat(isArabic ? 'h:mm a' : 'HH:mm', localeTag).format(spentAt.toLocal());
  }
}
