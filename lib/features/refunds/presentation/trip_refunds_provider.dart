import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/expense_refund.dart';

final tripRefundsProvider =
    FutureProvider.autoDispose.family<List<ExpenseRefund>, String>((ref, tripId) {
  return ref.watch(expenseRefundRepositoryProvider).getActiveRefundsByTrip(tripId);
});

/// Sums active refund face-value amounts per linked expense id.
Map<String, double> refundAmountsByExpenseId(List<ExpenseRefund> refunds) {
  final totals = <String, double>{};
  for (final refund in refunds) {
    final expenseId = refund.expenseId;
    if (expenseId == null || expenseId.isEmpty) {
      continue;
    }
    totals.update(expenseId, (value) => value + refund.amount, ifAbsent: () => refund.amount);
  }
  return totals;
}
