import '../domain/expense.dart';

/// Derived Quick Add data from a trip expense list in one pass.
class QuickAddExpenseSnapshot {
  const QuickAddExpenseSnapshot({
    required this.recentMerchants,
    required this.mostRecent,
  });

  final List<String> recentMerchants;
  final Expense? mostRecent;
}

/// Recent merchants and most-recent expense from [expenses] in a single sort.
QuickAddExpenseSnapshot deriveQuickAddSnapshot(
  List<Expense> expenses, {
  int maxCount = 7,
}) {
  if (expenses.isEmpty) {
    return const QuickAddExpenseSnapshot(
      recentMerchants: [],
      mostRecent: null,
    );
  }

  final sorted = List<Expense>.from(expenses)
    ..sort((a, b) => b.spentAt.compareTo(a.spentAt));

  final seenKeys = <String>{};
  final merchants = <String>[];

  for (final expense in sorted) {
    final name = expense.title.trim();
    if (name.isNotEmpty) {
      final key = name.toLowerCase();
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        merchants.add(name);
        if (merchants.length >= maxCount) {
          break;
        }
      }
    }
  }

  return QuickAddExpenseSnapshot(
    recentMerchants: merchants,
    mostRecent: sorted.first,
  );
}

/// Recent merchant names from [expenses] for the current trip only.
///
/// Sorted by most recent [Expense.spentAt], deduplicated case-insensitively,
/// empty titles ignored. Returns at most [maxCount] entries (default 7).
List<String> deriveRecentMerchants(
  List<Expense> expenses, {
  int maxCount = 7,
}) {
  return deriveQuickAddSnapshot(expenses, maxCount: maxCount).recentMerchants;
}

/// Most recent expense in [expenses] by [Expense.spentAt], or null if empty.
Expense? mostRecentExpense(List<Expense> expenses) {
  return deriveQuickAddSnapshot(expenses).mostRecent;
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
