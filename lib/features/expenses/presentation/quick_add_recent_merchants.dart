import '../domain/expense.dart';

/// Recent merchant names from [expenses] for the current trip only.
///
/// Sorted by most recent [Expense.spentAt], deduplicated case-insensitively,
/// empty titles ignored. Returns at most [maxCount] entries (default 7).
List<String> deriveRecentMerchants(
  List<Expense> expenses, {
  int maxCount = 7,
}) {
  if (expenses.isEmpty || maxCount <= 0) {
    return const [];
  }

  final sorted = List<Expense>.from(expenses)
    ..sort((a, b) => b.spentAt.compareTo(a.spentAt));

  final seenKeys = <String>{};
  final merchants = <String>[];

  for (final expense in sorted) {
    final name = expense.title.trim();
    if (name.isEmpty) {
      continue;
    }

    final key = name.toLowerCase();
    if (seenKeys.contains(key)) {
      continue;
    }

    seenKeys.add(key);
    merchants.add(name);
    if (merchants.length >= maxCount) {
      break;
    }
  }

  return merchants;
}

/// Most recent expense in [expenses] by [Expense.spentAt], or null if empty.
Expense? mostRecentExpense(List<Expense> expenses) {
  if (expenses.isEmpty) {
    return null;
  }
  final sorted = List<Expense>.from(expenses)
    ..sort((a, b) => b.spentAt.compareTo(a.spentAt));
  return sorted.first;
}

/// Title stored on save: merchant when provided, otherwise [category].
String resolveQuickAddExpenseTitle({
  required String merchantText,
  required String category,
}) {
  final merchant = merchantText.trim();
  if (merchant.isNotEmpty) {
    return merchant;
  }
  return category;
}
