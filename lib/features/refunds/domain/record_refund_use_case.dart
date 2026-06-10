import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../cash_wallet/data/cash_lot_repository.dart';
import '../../cash_wallet/data/cash_wallet_repository.dart';
import '../../cash_wallet/domain/cash_lot.dart';
import '../../expenses/domain/expense.dart';
import '../data/expense_refund_repository.dart';
import 'expense_refund.dart';
import 'refund_destination.dart';
import 'refund_inheritance_engine.dart';
import 'refund_result.dart';

/// Use case that records an expense refund atomically.
///
/// ## Cash Refund
///
/// 1. [RefundInheritanceEngine.planCashRefund] validates inputs and computes
///    the cost basis (including the over-refund guard using pre-fetched data).
/// 2. One SQLite transaction:
///    a. Assert over-refund guard (inside txn for ACID safety).
///    b. Insert returned [cash_lots] row
///       (source_type = 'cash_refund', source_ref_id patched after insert).
///    c. Insert [expense_refunds] row with [returned_lot_id] = lot.id.
///    d. Patch lot source_ref_id = refund.id.
///    e. Insert [cash_transactions] cashRefund row linked to the lot.
///    f. Update [trip_cash_balances] (+amount).
///
/// ## Card Refund
///
/// No Cash Lot, no cash transaction, no balance update.  One SQLite transaction:
///    a. Assert over-refund guard (inside txn).
///    b. Insert [expense_refunds] row.
///
/// ## Over-Refund Guard
///
/// For linked refunds, existing active refunds' home-total + new homeAmount
/// must not exceed the expense's convertedHomeAmount.  Checked both by the
/// engine (pre-flight, using pre-fetched data) and inside the transaction via
/// [ExpenseRefundRepository.assertOverRefundGuardTxn] (ACID check).
///
/// ## Atomicity
///
/// Any failure rolls back every cash refund write — no partial lot, no partial
/// refund row, no partial balance change.
class RecordRefundUseCase {
  RecordRefundUseCase({
    required AppDatabase appDatabase,
    required RefundInheritanceEngine refundEngine,
    required ExpenseRefundRepository refundRepository,
    required CashLotRepository lotRepository,
    required CashWalletRepository cashWalletRepository,
    Uuid? uuid,
  })  : _appDatabase = appDatabase,
        _refundEngine = refundEngine,
        _refundRepository = refundRepository,
        _lotRepository = lotRepository,
        _cashWalletRepository = cashWalletRepository,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final RefundInheritanceEngine _refundEngine;
  final ExpenseRefundRepository _refundRepository;
  final CashLotRepository _lotRepository;
  final CashWalletRepository _cashWalletRepository;
  final Uuid _uuid;

  /// Records a refund.
  ///
  /// [destination]    — [RefundDestination.cash] or [RefundDestination.card].
  /// [tripId]         — the trip this refund belongs to.
  /// [expenseId]      — the expense being refunded; null for unlinked refunds.
  /// [refundAmount]   — face-value refund amount (> 0).
  /// [refundCurrency] — ISO-4217 code of the refund currency.
  /// [homeAmount]     — home-currency amount; required for unlinked cash
  ///                    refunds; optional otherwise.
  /// [homeCurrency]   — required when [homeAmount] is non-null.
  /// [note]           — optional free-text note.
  /// [createdAt]      — timestamp; defaults to now.
  /// [linkedExpense]  — the full [Expense] object for the linked expense, used
  ///                    for over-refund guard and cost-basis derivation.
  ///
  /// Throws [ArgumentError] for invalid inputs.
  /// Throws [OverRefundException] when the refund would exceed the expense's
  /// home-currency total.
  Future<RefundResult> execute({
    required RefundDestination destination,
    required String tripId,
    String? expenseId,
    required double refundAmount,
    required String refundCurrency,
    double? homeAmount,
    String? homeCurrency,
    String? note,
    DateTime? createdAt,
    Expense? linkedExpense,
  }) async {
    // ── Pre-flight: fetch existing refunds total for over-refund check ────────
    double existingRefundsHomeTotal = 0.0;
    if (expenseId != null &&
        homeAmount != null &&
        linkedExpense?.convertedHomeAmount != null) {
      final existing =
          await _refundRepository.getActiveRefundsByExpense(expenseId);
      final homeCurrencyNorm = homeCurrency?.trim().toUpperCase() ??
          linkedExpense?.homeCurrency?.trim().toUpperCase();
      existingRefundsHomeTotal = existing
          .where((r) => r.homeAmount != null &&
              r.homeCurrency?.trim().toUpperCase() == homeCurrencyNorm)
          .fold(0.0, (sum, r) => sum + r.homeAmount!);
    }

    // ── Plan (validates + over-refund guard using pre-fetched total) ──────────
    final plan = destination == RefundDestination.cash
        ? _refundEngine.planCashRefund(
            expenseId: expenseId,
            refundAmount: refundAmount,
            refundCurrency: refundCurrency,
            homeAmount: homeAmount,
            homeCurrency: homeCurrency,
            linkedExpenseHomeAmount: linkedExpense?.convertedHomeAmount,
            linkedExpenseHomeCurrency: linkedExpense?.homeCurrency,
            existingRefundsHomeTotal: existingRefundsHomeTotal,
          )
        : _refundEngine.planCardRefund(
            expenseId: expenseId,
            refundAmount: refundAmount,
            refundCurrency: refundCurrency,
            homeAmount: homeAmount,
            homeCurrency: homeCurrency,
            linkedExpenseHomeAmount: linkedExpense?.convertedHomeAmount,
            linkedExpenseHomeCurrency: linkedExpense?.homeCurrency,
            existingRefundsHomeTotal: existingRefundsHomeTotal,
          );

    final timestamp = (createdAt ?? DateTime.now()).toUtc();
    final lotId = _uuid.v4();

    // ── Atomic transaction ─────────────────────────────────────────────────────
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      // ACID over-refund guard (re-check inside txn)
      await _refundRepository.assertOverRefundGuardTxn(
        txn,
        expenseId: expenseId,
        newHomeAmount: plan.inheritedHomeAmount,
        linkedExpense: linkedExpense,
      );

      if (plan.shouldCreateCashLot) {
        // ── Cash refund ────────────────────────────────────────────────────
        final effectiveRate = plan.effectiveRate;
        final lot = CashLot.create(
          id: lotId,
          tripId: tripId,
          sourceType: 'cash_refund',
          sourceRefType: 'expense_refund',
          sourceRefId: '', // placeholder — patched after refund insert
          currencyCode: plan.refundCurrency,
          originalAmount: plan.refundAmount,
          remainingAmount: plan.refundAmount,
          homeCurrencyAmount: plan.inheritedHomeAmount,
          homeCurrencyCode: plan.inheritedHomeCurrency,
          effectiveRate: effectiveRate,
          createdAt: timestamp,
          note: note,
        );

        // a. Insert lot (sourceRefId='')
        final insertedLot = await _lotRepository.insertCashLot(lot, txn: txn);

        // b. Insert refund row with returnedLotId
        final refund = ExpenseRefund.create(
          id: _uuid.v4(),
          tripId: tripId,
          expenseId: expenseId,
          amount: plan.refundAmount,
          currencyCode: plan.refundCurrency,
          homeAmount: plan.inheritedHomeAmount,
          homeCurrency: plan.inheritedHomeCurrency,
          destination: RefundDestination.cash,
          note: note,
          createdAt: timestamp,
          returnedLotId: insertedLot.id,
        );
        await _refundRepository.insertRefundTxn(txn, refund);

        // c. Patch lot source_ref_id = refund.id
        await _lotRepository.updateLotSourceRef(
          lotId: insertedLot.id,
          sourceRefId: refund.id,
          txn: txn,
        );

        // d. Cash transaction + balance update
        final cashTx = await _cashWalletRepository.recordCashRefundInflow(
          txn: txn,
          tripId: tripId,
          expenseId: expenseId,
          amount: plan.refundAmount,
          currencyCode: plan.refundCurrency,
          lotId: insertedLot.id,
          homeCurrencyAmount: plan.inheritedHomeAmount,
          homeCurrencyCode: plan.inheritedHomeCurrency,
          note: note,
          createdAt: timestamp,
        );

        return RefundResult(
          refund: refund,
          cashLot: insertedLot.copyWith(sourceRefId: refund.id),
          cashTransaction: cashTx,
        );
      } else {
        // ── Card refund ───────────────────────────────────────────────────
        final refund = ExpenseRefund.create(
          id: _uuid.v4(),
          tripId: tripId,
          expenseId: expenseId,
          amount: plan.refundAmount,
          currencyCode: plan.refundCurrency,
          homeAmount: plan.inheritedHomeAmount,
          homeCurrency: plan.inheritedHomeCurrency,
          destination: RefundDestination.card,
          note: note,
          createdAt: timestamp,
          returnedLotId: null,
        );
        await _refundRepository.insertRefundTxn(txn, refund);

        return RefundResult(
          refund: refund,
          cashLot: null,
          cashTransaction: null,
        );
      }
    });
  }
}
