import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_use_case.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';

/// Test-only [UpdateCashExpenseUseCase] that bypasses FIFO lot planning and
/// avoids opening any real SQLite database.
///
/// For cash→cash edits, preserves the existing [Expense.conversionRate]
/// snapshot and recalculates [Expense.convertedHomeAmount] using
/// `amount × storedRate`.  All other fields are passed through unchanged.
///
/// For [reverseAndDelete], simply forwards to the injected [ExpenseRepository].
///
/// Use to override [updateCashExpenseUseCaseProvider] in widget / unit tests
/// that do not set up cash-lot fixtures:
///
/// ```dart
/// updateCashExpenseUseCaseProvider.overrideWith((ref) {
///   return NoFifoUpdateCashExpenseUseCase(
///     expenseRepository: ref.watch(expenseRepositoryProvider),
///   );
/// }),
/// ```
class NoFifoUpdateCashExpenseUseCase extends UpdateCashExpenseUseCase {
  // ignore: use_super_parameters
  NoFifoUpdateCashExpenseUseCase({
    required ExpenseRepository expenseRepository,
  })  : _bypassExpenseRepo = expenseRepository,
        super(
          // These objects are stored by super but never used because both
          // execute() and reverseAndDelete() are overridden below.
          // AppDatabase() is lazy — it only opens the file when .database is
          // awaited, so sqfliteFfi is not required here.
          appDatabase: AppDatabase(),
          expenseRepository: expenseRepository,
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
          fifoEngine: CashLotFifoEngine(CashLotRepository(AppDatabase())),
          refundRepository: ExpenseRefundRepository(AppDatabase()),
        );

  final ExpenseRepository _bypassExpenseRepo;

  @override
  Future<UpdateCashExpenseResult> execute(Expense updatedExpense) async {
    // Preserve the stored conversionRate snapshot; recalculate home amount.
    final previous = await _bypassExpenseRepo.getExpenseById(updatedExpense.id);
    final storedRate = previous?.conversionRate ?? updatedExpense.conversionRate;
    final homeAmount = (storedRate != null)
        ? updatedExpense.amount * storedRate
        : updatedExpense.convertedHomeAmount;

    final toSave = updatedExpense.copyWith(
      conversionRate: storedRate,
      convertedHomeAmount: homeAmount,
    );
    final saved = await _bypassExpenseRepo.updateExpense(toSave);
    return UpdateCashExpenseResult(expense: saved);
  }

  @override
  Future<void> reverseAndDelete(String expenseId) async {
    final expense = await _bypassExpenseRepo.getExpenseById(expenseId);
    if (expense == null || expense.isReversed) return;
    // Soft-delete: mark reversed so getExpensesByTrip filters it out.
    await _bypassExpenseRepo.updateExpense(
      expense.copyWith(isReversed: true, reversedAt: DateTime.now().toUtc()),
    );
  }
}
