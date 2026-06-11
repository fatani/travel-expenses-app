import '../../../core/database/app_database.dart';
import '../../cash_wallet/data/cash_lot_consumption_repository.dart';
import '../../cash_wallet/data/cash_lot_repository.dart';
import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../../cash_wallet/domain/cash_lot_consumption.dart';
import '../../cash_wallet/domain/cash_lot_fifo_engine.dart';
import '../../cash_wallet/domain/insufficient_cash_exception.dart';
import '../../refunds/data/expense_refund_repository.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import '../domain/expense_payment_service.dart';
import 'update_cash_expense_exception.dart';

/// Result returned by [UpdateCashExpenseUseCase.execute].
class UpdateCashExpenseResult {
  const UpdateCashExpenseResult({required this.expense});

  /// The persisted expense, with FIFO-derived cost basis when the new payment
  /// method is cash.
  final Expense expense;
}

/// Atomically updates a cash (or previously-cash) expense using FIFO lot
/// accounting.
///
/// ## Reverse + Recreate contract
///
/// All writes happen inside a single SQLite transaction.  If any step fails
/// (including [InsufficientCashException] from the FIFO engine) the database
/// is left unchanged.
///
/// **Reverse phase** (runs when the _previous_ expense was cash AND the
/// financial terms changed):
/// 1. Restore each affected lot's [remaining_amount] by the consumed delta.
/// 2. Mark consumption rows `is_reversed = 1`.
/// 3. Mark the `cash_transactions` deduction row `is_reversed = 1` and
///    restore `trip_cash_balances`.
///
/// **Recreate phase** (runs when the _new_ expense is cash AND the financial
/// terms changed):
/// 4. Plan FIFO consumption for the new amount — now sees restored lots.
/// 5. Write new `cash_lot_consumptions` rows.
/// 6. Decrement `cash_lots.remaining_amount` per plan.
/// 7. Record a new `cash_transactions` deduction and update
///    `trip_cash_balances`.
///
/// **Update phase** (always):
/// 8. Persist the updated `expenses` row with FIFO-derived
///    [convertedHomeAmount] / [conversionRate] (or the caller-supplied values
///    when the new payment is not cash).
///
/// ## No-op optimisation
/// When both sides are cash with identical [transactionAmount] and
/// [transactionCurrency], the lot tables are untouched and only the
/// `expenses` row is updated (preserving the original FIFO snapshot).
///
/// ## Rejection rules (pre-transaction, no DB writes)
/// - [UpdateCashExpenseFailureReason.alreadyReversed] — the stored expense has
///   `is_reversed = 1`.
/// - [UpdateCashExpenseFailureReason.hasActiveRefunds] — one or more active
///   refunds exist for the expense.
/// - [UpdateCashExpenseFailureReason.insufficientCash] — after lot restoration
///   the available balance is still insufficient for the new amount.
class UpdateCashExpenseUseCase {
  const UpdateCashExpenseUseCase({
    required AppDatabase appDatabase,
    required ExpenseRepository expenseRepository,
    required CashLotConsumptionRepository consumptionRepository,
    required CashLotRepository lotRepository,
    required CashWalletRepository cashWalletRepository,
    required CashLotFifoEngine fifoEngine,
    required ExpenseRefundRepository refundRepository,
  })  : _appDatabase = appDatabase,
        _expenseRepository = expenseRepository,
        _consumptionRepository = consumptionRepository,
        _lotRepository = lotRepository,
        _cashWalletRepository = cashWalletRepository,
        _fifoEngine = fifoEngine,
        _refundRepository = refundRepository;

  final AppDatabase _appDatabase;
  final ExpenseRepository _expenseRepository;
  final CashLotConsumptionRepository _consumptionRepository;
  final CashLotRepository _lotRepository;
  final CashWalletRepository _cashWalletRepository;
  final CashLotFifoEngine _fifoEngine;
  final ExpenseRefundRepository _refundRepository;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Executes the cash-expense update.
  ///
  /// [updatedExpense] carries all desired new values.  Its [Expense.id] must
  /// match an existing non-reversed expense.
  ///
  /// When the new payment method is cash, [convertedHomeAmount] and
  /// [conversionRate] are derived from FIFO and any caller-supplied values are
  /// discarded.  When the new payment method is _not_ cash, the caller is
  /// responsible for supplying a valid FX snapshot in [updatedExpense].
  ///
  /// Returns the persisted expense.  Throws [UpdateCashExpenseException] on
  /// rejection, or re-throws unexpected repository errors.
  Future<UpdateCashExpenseResult> execute(Expense updatedExpense) async {
    final expenseId = updatedExpense.id;

    // --- Pre-flight checks (no DB writes) -----------------------------------

    final previous = await _expenseRepository.getExpenseById(expenseId);
    if (previous == null || previous.isReversed) {
      throw const UpdateCashExpenseException(
        UpdateCashExpenseFailureReason.alreadyReversed,
      );
    }

    final refunds =
        await _refundRepository.getActiveRefundsByExpense(expenseId);
    if (refunds.isNotEmpty) {
      throw const UpdateCashExpenseException(
        UpdateCashExpenseFailureReason.hasActiveRefunds,
      );
    }

    final previousWasCash = _isCash(previous);
    final nextIsCash = _isCash(updatedExpense);

    // Metadata-only edit: same cash amount + currency → skip lot operations.
    final cashAmountUnchanged = previousWasCash &&
        nextIsCash &&
        (previous.transactionAmount - updatedExpense.transactionAmount).abs() <
            1e-9 &&
        previous.transactionCurrency.trim().toUpperCase() ==
            updatedExpense.transactionCurrency.trim().toUpperCase();

    // Load active (non-reversed) consumptions before opening the transaction.
    final List<CashLotConsumption> activeConsumptions;
    if (previousWasCash && !cashAmountUnchanged) {
      final all =
          await _consumptionRepository.getConsumptionsByExpenseId(expenseId);
      activeConsumptions = all.where((c) => !c.isReversed).toList();
    } else {
      activeConsumptions = const [];
    }

    // --- Atomic transaction -------------------------------------------------

    final db = await _appDatabase.database;
    final Expense saved;
    try {
      saved = await db.transaction((txn) async {
        // 1. Reverse phase ─ restore lots, mark consumptions reversed, reverse
        //    the cash_transactions deduction.
        if (previousWasCash && !cashAmountUnchanged) {
          for (final c in activeConsumptions) {
            await _lotRepository.restoreLotConsumption(
              c.lotId,
              c.consumedAmount,
              txn: txn,
            );
          }
          await _consumptionRepository.markConsumptionsReversedForExpense(
            txn,
            expenseId,
          );
          await _cashWalletRepository.reverseCashExpenseDeductionInTxn(
            txn,
            tripId: previous.tripId,
            expenseId: expenseId,
          );
        }

        // 2. Recreate phase ─ plan FIFO (sees restored lots via txn), write
        //    new consumptions + deduction.
        Expense expenseToSave;

        if (nextIsCash && !cashAmountUnchanged) {
          // planConsumption uses the txn so it sees the restored lot state.
          final plans = await _fifoEngine.planConsumption(
            tripId: updatedExpense.tripId,
            currencyCode: updatedExpense.transactionCurrency,
            requiredAmount: updatedExpense.transactionAmount,
            txn: txn,
          );

          // Derive FIFO cost basis.
          double? totalHomeAmount;
          String? homeCurrencyCode;
          for (final plan in plans) {
            final h = plan.homeAmount;
            if (h != null) {
              totalHomeAmount = (totalHomeAmount ?? 0.0) + h;
              homeCurrencyCode ??= plan.homeCurrencyCode;
            }
          }
          final conversionRate = (totalHomeAmount != null &&
                  updatedExpense.transactionAmount > 0)
              ? totalHomeAmount / updatedExpense.transactionAmount
              : null;

          expenseToSave = updatedExpense.copyWith(
            convertedHomeAmount: totalHomeAmount,
            homeCurrency: homeCurrencyCode,
            conversionRate: conversionRate,
          );

          // Write new lot-consumption rows.
          for (final plan in plans) {
            final consumption = CashLotConsumption.create(
              lotId: plan.lotId,
              consumptionType: 'cash_expense',
              expenseId: expenseId,
              consumedAmount: plan.consumedAmount,
              homeAmount: plan.homeAmount,
              homeCurrencyCode: plan.homeCurrencyCode,
            );
            await _consumptionRepository.insertConsumption(
              consumption,
              txn: txn,
            );
            await _lotRepository.updateLotRemainingAmount(
              plan.lotId,
              plan.remainingAmountAfter,
              txn: txn,
            );
          }

          // Record new cash_transactions deduction + update trip_cash_balances.
          await _cashWalletRepository.recordCashExpenseDeduction(
            tripId: expenseToSave.tripId,
            expenseId: expenseId,
            amount: expenseToSave.transactionAmount,
            currencyCode: expenseToSave.transactionCurrency,
            note: expenseToSave.note,
            txn: txn,
          );
        } else if (nextIsCash && cashAmountUnchanged) {
          // Metadata-only edit: keep the original FIFO snapshot unchanged.
          expenseToSave = updatedExpense.copyWith(
            convertedHomeAmount: previous.convertedHomeAmount,
            homeCurrency: previous.homeCurrency,
            conversionRate: previous.conversionRate,
          );
        } else {
          // New payment is not cash (cash → card transition): the caller has
          // already resolved the card FX snapshot into updatedExpense.
          expenseToSave = updatedExpense;
        }

        // 3. Update phase ─ persist the expense row.
        return _expenseRepository.updateExpense(expenseToSave, txn: txn);
      });
    } on InsufficientCashException catch (e) {
      throw UpdateCashExpenseException(
        UpdateCashExpenseFailureReason.insufficientCash,
        underlyingException: e,
      );
    }

    return UpdateCashExpenseResult(expense: saved);
  }

  /// Reverses FIFO lot state for [expenseId] and hard-deletes the expense row,
  /// all within a single atomic transaction.
  ///
  /// If the expense does not exist or is not a cash expense, only the delete
  /// is performed (no lot operations).
  Future<void> reverseAndDelete(String expenseId) async {
    final existing = await _expenseRepository.getExpenseById(expenseId);
    if (existing == null) return;

    final wasCash = _isCash(existing);
    final List<CashLotConsumption> activeConsumptions;
    if (wasCash) {
      final all =
          await _consumptionRepository.getConsumptionsByExpenseId(expenseId);
      activeConsumptions = all.where((c) => !c.isReversed).toList();
    } else {
      activeConsumptions = const [];
    }

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      if (wasCash) {
        for (final c in activeConsumptions) {
          await _lotRepository.restoreLotConsumption(
            c.lotId,
            c.consumedAmount,
            txn: txn,
          );
        }
        // Hard-delete consumption rows BEFORE deleting the expense row.
        // The schema has FOREIGN KEY (expense_id) ON DELETE SET NULL plus a
        // CHECK (expense_id IS NOT NULL) on cash_expense rows — they conflict
        // when deleting the expense.  Removing the rows first prevents the FK
        // trigger from firing.  Lot state is already restored above; the
        // cash_transactions reversal below preserves the audit trail.
        await _consumptionRepository.deleteConsumptionsByExpenseId(
          expenseId,
          txn: txn,
        );
        await _cashWalletRepository.reverseCashExpenseDeductionInTxn(
          txn,
          tripId: existing.tripId,
          expenseId: expenseId,
        );
      }
      await _expenseRepository.deleteExpense(expenseId, txn: txn);
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static bool _isCash(Expense expense) => isCashExpensePayment(
        paymentMethod: expense.paymentMethod,
        paymentChannel: expense.paymentChannel,
      );
}
