import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';

/// In-memory and fake expense repositories used in widget tests should extend
/// this type so cash expense creation stays compatible with controller flows.
abstract class TestExpenseRepository extends ExpenseRepository {
  TestExpenseRepository([AppDatabase? appDatabase])
      : super(appDatabase ?? AppDatabase());

  @override
  Future<CashExpenseCreateResult> createCashExpenseWithWalletDeduction({
    required Expense expense,
    required CashWalletRepository cashWallet,
  }) async {
    final created = await createExpense(expense);
    final deduction = await cashWallet.recordCashExpenseDeduction(
      tripId: created.tripId,
      expenseId: created.id,
      amount: created.transactionAmount,
      currencyCode: created.transactionCurrency,
      note: created.note,
    );

    return CashExpenseCreateResult(expense: created, deduction: deduction);
  }
}
