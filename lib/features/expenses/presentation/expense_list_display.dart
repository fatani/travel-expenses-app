import '../domain/expense.dart';

enum ExpenseListSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount,
}

/// Pure filter/sort/total helpers for trip expense lists.
class ExpenseListDisplay {
  const ExpenseListDisplay._();

  static List<Expense> filteredAndSorted({
    required List<Expense> expenses,
    required String searchQuery,
    String? category,
    String? paymentMethod,
    ExpenseListSort sort = ExpenseListSort.newestFirst,
  }) {
    final filtered = expenses.where((expense) {
      if (category != null && expense.category != category) {
        return false;
      }
      if (paymentMethod != null && expense.paymentMethod != paymentMethod) {
        return false;
      }
      if (searchQuery.isEmpty) {
        return true;
      }

      final haystack =
          '${expense.title} ${expense.note ?? ''} ${expense.rawSmsText ?? ''}'
              .toLowerCase();
      return haystack.contains(searchQuery);
    }).toList();

    filtered.sort((a, b) {
      switch (sort) {
        case ExpenseListSort.newestFirst:
          return b.spentAt.compareTo(a.spentAt);
        case ExpenseListSort.oldestFirst:
          return a.spentAt.compareTo(b.spentAt);
        case ExpenseListSort.highestAmount:
          return b.transactionAmount.compareTo(a.transactionAmount);
        case ExpenseListSort.lowestAmount:
          return a.transactionAmount.compareTo(b.transactionAmount);
      }
    });

    return filtered;
  }

  /// Search/category/payment filters that hide the full-trip context total.
  static bool hidesContextTotal({
    required String searchQuery,
    String? category,
    String? paymentMethod,
  }) {
    return searchQuery.isNotEmpty ||
        category != null ||
        paymentMethod != null;
  }

  /// Returns the single transaction currency when all expenses share one.
  static String? soleTransactionCurrency(List<Expense> expenses) {
    String? sole;
    for (final expense in expenses) {
      final currency = expense.transactionCurrency.trim().toUpperCase();
      if (currency.isEmpty) {
        continue;
      }
      if (sole == null) {
        sole = currency;
      } else if (sole != currency) {
        return null;
      }
    }
    return sole;
  }

  static double soleCurrencyTotal(List<Expense> expenses, String currency) {
    return expenses.fold<double>(
      0,
      (sum, expense) =>
          expense.transactionCurrency.trim().toUpperCase() == currency
          ? sum + expense.transactionAmount
          : sum,
    );
  }
}
