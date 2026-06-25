import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';

/// Test double that reports no active refunds for any expense.
///
/// Use when card→card edit tests do not set up SQLite but must satisfy the
/// active-refund guard in [ExpenseController.updateExpense].
class EmptyExpenseRefundRepository extends ExpenseRefundRepository {
  EmptyExpenseRefundRepository() : super(AppDatabase());

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByExpense(
    String expenseId,
  ) async =>
      const [];
}
