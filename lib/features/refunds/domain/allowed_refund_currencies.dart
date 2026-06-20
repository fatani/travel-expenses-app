import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_payment_service.dart';

/// Builds the ordered, de-duplicated list of currencies a trip-level refund may
/// be recorded in.
///
/// Order (per spec):
///   1. Trip home currency.
///   2. Trip destination currency.
///   3. Currencies previously used by **card-paid** expenses in this trip.
///
/// Rules:
///   * Codes are trimmed/upper-cased; empties are skipped.
///   * Duplicates are removed, preserving first-seen order (so `home ==
///     destination` collapses to a single entry, and a prior card currency that
///     duplicates home/destination is not repeated).
///   * Only **card-like** expenses contribute prior currencies — cash-only
///     currencies are excluded.
///   * Reversed expenses are ignored (they are not active financial data).
List<String> buildAllowedRefundCurrencies({
  required String homeCurrency,
  required String destinationCurrency,
  required Iterable<Expense> expenses,
}) {
  final ordered = <String>[];

  void add(String? raw) {
    final code = raw?.trim().toUpperCase();
    if (code == null || code.isEmpty) return;
    if (ordered.contains(code)) return;
    ordered.add(code);
  }

  add(homeCurrency);
  add(destinationCurrency);

  for (final expense in expenses) {
    if (expense.isReversed) continue;
    final isCash = isCashExpensePayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
    if (isCash) continue;
    add(expense.transactionCurrency);
  }

  return ordered;
}
