import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/expense_payment_service.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_use_case.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';

/// Test-only [UpdateCashExpenseUseCase] that bypasses FIFO lot planning and
/// avoids opening any real SQLite database.
///
/// Mirrors the production contract without a database:
/// * Cash destination: the FX snapshot is FIFO-derived in production. Here the
///   rate is stubbed with [fifoRate] when provided, otherwise the existing
///   stored [Expense.conversionRate] is preserved; the home amount is
///   recalculated as `amount × rate`.
/// * Card destination (cash → card edits): the expense is saved as-is — the
///   controller already resolved the card snapshot.
///
/// For [reverseAndDelete], marks the expense reversed via the injected
/// [ExpenseRepository] (soft delete).
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
    this.fifoRate,
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

  /// Stub for the FIFO-derived effective rate applied to cash destinations.
  final double? fifoRate;

  @override
  Future<UpdateCashExpenseResult> execute(Expense updatedExpense) async {
    final nextIsCash = isCashExpensePayment(
      paymentMethod: updatedExpense.paymentMethod,
      paymentChannel: updatedExpense.paymentChannel,
    );

    // Cash → card edits: the controller already resolved the card snapshot;
    // production saves the expense as-is after reversing old consumptions.
    if (!nextIsCash) {
      final saved = await _bypassExpenseRepo.updateExpense(updatedExpense);
      return UpdateCashExpenseResult(expense: saved);
    }

    // Cash destination: stub the FIFO-derived rate, falling back to the
    // previously stored snapshot rate; recalculate the home amount.
    final previous = await _bypassExpenseRepo.getExpenseById(updatedExpense.id);
    final storedRate = fifoRate ??
        previous?.conversionRate ??
        updatedExpense.conversionRate;
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
