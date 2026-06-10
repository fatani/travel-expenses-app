import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../cash_wallet/data/cash_lot_consumption_repository.dart';
import '../../cash_wallet/data/cash_lot_repository.dart';
import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../../cash_wallet/domain/cash_lot_consumption.dart';
import '../../cash_wallet/domain/cash_lot_fifo_engine.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

/// Use case that records a cash expense with full FIFO lot consumption.
///
/// ## Transaction contract
/// All writes happen inside a single SQLite transaction.  If any step fails
/// (including [InsufficientCashException] from the FIFO engine, which is thrown
/// *before* the transaction opens), the database is left unchanged.
///
/// ## Steps
/// 1. Run [CashLotFifoEngine.planConsumption] — fails fast on insufficient balance.
/// 2. Derive FIFO cost basis: `SUM(plan.homeAmount)`.
/// 3. Open transaction:
///    a. Insert expense (with FIFO-derived `convertedHomeAmount`).
///    b. Insert [cash_lot_consumptions] row per plan step.
///    c. Update [cash_lots.remaining_amount] (and `is_fully_consumed`) per lot.
///    d. Insert `cash_transactions` row (type = `cash_expense_deduction`,
///       `lot_id = NULL`, `exchange_id = NULL`).
///    e. Update `trip_cash_balances`.
///
/// ## Cost-basis rule
/// ```
/// expense.convertedHomeAmount = SUM(plan.homeAmount)   // null when all null
/// expense.conversionRate      = convertedHomeAmount / transactionAmount
/// ```
class RecordCashExpenseUseCase {
  RecordCashExpenseUseCase({
    required AppDatabase appDatabase,
    required ExpenseRepository expenseRepository,
    required CashWalletRepository cashWalletRepository,
    required CashLotFifoEngine fifoEngine,
    required CashLotRepository lotRepository,
    required CashLotConsumptionRepository consumptionRepository,
    Uuid? uuid,
  })  : _appDatabase = appDatabase,
        _expenseRepository = expenseRepository,
        _cashWalletRepository = cashWalletRepository,
        _fifoEngine = fifoEngine,
        _lotRepository = lotRepository,
        _consumptionRepository = consumptionRepository,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final ExpenseRepository _expenseRepository;
  final CashWalletRepository _cashWalletRepository;
  final CashLotFifoEngine _fifoEngine;
  final CashLotRepository _lotRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final Uuid _uuid;

  /// Records [expense] as a cash expense, consuming FIFO lots and writing all
  /// related rows atomically.
  ///
  /// The returned [CashExpenseCreateResult.expense] has its
  /// `convertedHomeAmount`, `homeCurrency`, and `conversionRate` replaced with
  /// the FIFO-derived values.
  ///
  /// Throws [InsufficientCashException] (from the FIFO engine) when the wallet
  /// lacks sufficient balance.  No DB writes occur in that case.
  Future<CashExpenseCreateResult> execute(Expense expense) async {
    // --- 1. Plan FIFO consumption (no DB writes yet) -----------------------
    final plans = await _fifoEngine.planConsumption(
      tripId: expense.tripId,
      currencyCode: expense.transactionCurrency,
      requiredAmount: expense.transactionAmount,
    );

    // --- 2. Derive cost basis from plan ------------------------------------
    double? totalHomeAmount;
    String? homeCurrencyCode;
    for (final plan in plans) {
      final h = plan.homeAmount;
      if (h != null) {
        totalHomeAmount = (totalHomeAmount ?? 0.0) + h;
        homeCurrencyCode ??= plan.homeCurrencyCode;
      }
    }
    final conversionRate =
        (totalHomeAmount != null && expense.transactionAmount > 0)
            ? totalHomeAmount / expense.transactionAmount
            : null;

    // Pre-assign stable ID so it is available inside the transaction for the
    // consumption records before createExpense stamps it.
    final expenseId =
        expense.id.trim().isEmpty ? _uuid.v4() : expense.id.trim();

    // Apply FIFO cost basis (may set null to clear a prior snapshot).
    final expenseWithBasis = expense.copyWith(
      id: expenseId,
      convertedHomeAmount: totalHomeAmount,
      homeCurrency: homeCurrencyCode,
      conversionRate: conversionRate,
    );

    // --- 3. Execute all writes inside one transaction ----------------------
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      // 3a. Insert expense (createExpense stamps updatedAt and validates).
      final created =
          await _expenseRepository.createExpense(expenseWithBasis, txn: txn);

      // 3b–3c. Consume lots.
      for (final plan in plans) {
        final consumption = CashLotConsumption.create(
          lotId: plan.lotId,
          consumptionType: 'cash_expense',
          expenseId: created.id,
          consumedAmount: plan.consumedAmount,
          homeAmount: plan.homeAmount,
          homeCurrencyCode: plan.homeCurrencyCode,
        );
        await _consumptionRepository.insertConsumption(consumption, txn: txn);
        await _lotRepository.updateLotRemainingAmount(
          plan.lotId,
          plan.remainingAmountAfter,
          txn: txn,
        );
      }

      // 3d–3e. Insert cash_transactions row and update trip_cash_balances.
      // recordCashExpenseDeduction reuses the established pattern; when
      // called with txn it participates in our outer transaction.
      final deduction = await _cashWalletRepository.recordCashExpenseDeduction(
        tripId: created.tripId,
        expenseId: created.id,
        amount: created.transactionAmount,
        currencyCode: created.transactionCurrency,
        note: created.note,
        txn: txn,
      );

      return CashExpenseCreateResult(expense: created, deduction: deduction);
    });
  }
}
