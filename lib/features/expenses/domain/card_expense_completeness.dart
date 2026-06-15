import 'expense.dart';
import 'expense_payment.dart';

/// Returns whether [expense] is a cross-currency card expense still missing
/// the user-provided charged home amount.
///
/// Derived only from existing expense + trip data. Never persisted.
bool isPendingCardExpense({
  required Expense expense,
  required String tripHomeCurrency,
}) {
  if (expense.isReversed) {
    return false;
  }

  if (!isCardExpenseChannel(expense.paymentChannel)) {
    return false;
  }

  final transactionCurrency = expense.transactionCurrency.trim().toUpperCase();
  final homeCurrency = tripHomeCurrency.trim().toUpperCase();
  if (transactionCurrency.isEmpty ||
      homeCurrency.isEmpty ||
      transactionCurrency == homeCurrency) {
    return false;
  }

  final chargedAmount = expense.totalChargedAmount;
  return chargedAmount == null || chargedAmount <= 0;
}

/// Counts pending card expenses in [expenses] for report transparency.
int countPendingCardExpenses({
  required Iterable<Expense> expenses,
  required String tripHomeCurrency,
}) {
  if (tripHomeCurrency.trim().isEmpty) {
    return 0;
  }

  return expenses
      .where(
        (expense) => isPendingCardExpense(
          expense: expense,
          tripHomeCurrency: tripHomeCurrency,
        ),
      )
      .length;
}
