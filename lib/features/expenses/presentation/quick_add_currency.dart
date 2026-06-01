import '../../trips/domain/trip.dart';
import '../domain/expense.dart';

/// Sentinel returned when the user chooses "Other currency..." in the picker.
const String kQuickAddCurrencyPickerOther = '__quick_add_other_currency__';

/// Options shown in the Quick Add currency bottom sheet.
class QuickAddCurrencyPickerOptions {
  const QuickAddCurrencyPickerOptions({
    required this.tripCurrencies,
    required this.recentCurrencies,
  });

  final List<String> tripCurrencies;
  final List<String> recentCurrencies;

  List<String> get allListedCodes => [
        ...tripCurrencies,
        ...recentCurrencies,
      ];
}

/// Trip currencies in product order: base, destination (if different), home snapshot (if different).
List<String> deriveQuickAddTripCurrencies(Trip trip) {
  final seen = <String>{};
  final result = <String>[];

  void add(String raw) {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty || seen.contains(code)) {
      return;
    }
    seen.add(code);
    result.add(code);
  }

  add(trip.baseCurrency);
  add(trip.destinationCurrency);
  add(trip.homeCurrencySnapshot);
  return result;
}

/// Recent expense currencies, most recent first, excluding [exclude], capped at [maxCount].
List<String> deriveQuickAddRecentCurrencies(
  List<Expense> expenses, {
  required Set<String> exclude,
  int maxCount = 3,
}) {
  if (expenses.isEmpty || maxCount <= 0) {
    return const [];
  }

  final sorted = List<Expense>.from(expenses)
    ..sort((a, b) => b.spentAt.compareTo(a.spentAt));

  final seen = <String>{};
  final result = <String>[];

  for (final expense in sorted) {
    final code = expense.currencyCode.trim().toUpperCase();
    if (code.isEmpty || exclude.contains(code) || seen.contains(code)) {
      continue;
    }
    seen.add(code);
    result.add(code);
    if (result.length >= maxCount) {
      break;
    }
  }

  return result;
}

QuickAddCurrencyPickerOptions buildQuickAddCurrencyPickerOptions(
  Trip trip,
  List<Expense> expenses,
) {
  final tripCurrencies = deriveQuickAddTripCurrencies(trip);
  final exclude = tripCurrencies.toSet();
  final recentCurrencies = deriveQuickAddRecentCurrencies(
    expenses,
    exclude: exclude,
  );
  return QuickAddCurrencyPickerOptions(
    tripCurrencies: tripCurrencies,
    recentCurrencies: recentCurrencies,
  );
}

/// Exactly three alphabetic characters (ISO-style code entry).
bool isValidQuickAddOtherCurrencyCode(String value) {
  final normalized = normalizeQuickAddCurrencyCode(value);
  return RegExp(r'^[A-Z]{3}$').hasMatch(normalized);
}

String normalizeQuickAddCurrencyCode(String value) =>
    value.trim().toUpperCase();
