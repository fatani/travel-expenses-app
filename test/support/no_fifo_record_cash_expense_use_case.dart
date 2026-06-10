import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';

/// Test-only [RecordCashExpenseUseCase] that bypasses FIFO lot planning.
///
/// Passes the expense through to the [ExpenseRepository] unchanged,
/// preserving any FX-snapshot values set by the controller.
/// Returns a dummy [CashExpenseDeductionResult] so no real database access
/// is needed for the wallet deduction step.
///
/// Use to override [recordCashExpenseUseCaseProvider] in widget/unit tests
/// that do not set up cash-lot fixtures.
///
/// ```dart
/// recordCashExpenseUseCaseProvider.overrideWith((ref) {
///   return NoFifoRecordCashExpenseUseCase(
///     expenseRepository: ref.watch(expenseRepositoryProvider),
///     cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
///   );
/// }),
/// ```
class NoFifoRecordCashExpenseUseCase extends RecordCashExpenseUseCase {
  // ignore: use_super_parameters — expenseRepository is also stored locally.
  NoFifoRecordCashExpenseUseCase({
    required ExpenseRepository expenseRepository,
    required CashWalletRepository cashWalletRepository,
  })  : _bypassExpenseRepo = expenseRepository,
        super(
          // These objects are stored by super but never accessed because
          // execute() is overridden below. AppDatabase() is lazy — it only
          // opens the file when .database is awaited, so sqfliteFfi is not
          // required here.
          appDatabase: AppDatabase(),
          expenseRepository: expenseRepository,
          cashWalletRepository: cashWalletRepository,
          fifoEngine: CashLotFifoEngine(CashLotRepository(AppDatabase())),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository: CashLotConsumptionRepository(AppDatabase()),
        );

  final ExpenseRepository _bypassExpenseRepo;

  @override
  Future<CashExpenseCreateResult> execute(Expense expense) async {
    // Bypass FIFO: delegate directly to the (possibly fake) expense repository.
    // The expense is passed through unchanged so the controller's FX-snapshot
    // values (convertedHomeAmount, homeCurrency, conversionRate) are preserved.
    final created = await _bypassExpenseRepo.createExpense(expense);
    return CashExpenseCreateResult(
      expense: created,
      deduction: const CashExpenseDeductionResult(
        wasInsufficientBeforeDeduction: false,
        balanceAfterDeduction: 0,
      ),
    );
  }
}
