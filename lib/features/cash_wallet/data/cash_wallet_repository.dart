import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/integrity/data_integrity.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_payment.dart';
import '../domain/cash_lot.dart';
import '../domain/cash_transaction.dart';
import '../domain/cash_effective_rate_calculator.dart';
import '../domain/trip_cash_balance.dart';

class CashExpenseDeductionResult {
  const CashExpenseDeductionResult({
    required this.wasInsufficientBeforeDeduction,
    required this.balanceAfterDeduction,
  });

  final bool wasInsufficientBeforeDeduction;
  final double balanceAfterDeduction;
}

class CashWalletRepository {
  CashWalletRepository(this._appDatabase, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tripCashBalancesTable,
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'currency_code ASC',
    );

    return rows.map(TripCashBalance.fromMap).toList();
  }

  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async {
    final db = await _appDatabase.database;
    final whereClause = includeReversed
        ? 'trip_id = ?'
        : 'trip_id = ? AND is_reversed = 0';
    final rows = await db.query(
      AppDatabase.cashTransactionsTable,
      where: whereClause,
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    return rows.map(CashTransaction.fromMap).toList();
  }

  /// Records a manual cash transaction (initial cash, manual adjustment, …).
  ///
  /// Sprint 9A: cash **inflows** recorded through this method also create a
  /// FIFO [cash_lots] row inside the same transaction, so cash entered via
  /// the production UI (trip setup, Add Cash sheet) is spendable by
  /// `RecordCashExpenseUseCase` and visible to lot-based reporting.
  ///
  /// Lot linkage contract:
  /// * `cash_transactions.lot_id`   = lot.id
  /// * `cash_lots.source_ref_type`  = 'cash_transaction'
  /// * `cash_lots.source_ref_id`    = cash_transaction.id
  ///
  /// Cost-basis rule: when a positive [homeCurrencyAmount] (and
  /// [homeCurrencyCode]) is provided the lot carries
  /// `effective_rate = homeCurrencyAmount / amount`; otherwise the lot is
  /// created without a basis (all three basis columns null).
  ///
  /// All writes (transaction row, lot row, balance upsert) are atomic: a
  /// failure leaves no partial state behind.
  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    // Financial Core invariant (defense in depth): a currency-exchange inflow
    // must never be created on its own. Every exchange-in lot requires a
    // matching exchange-out consumption, source lot chain, transferred cost
    // basis, and a currency_exchanges record — all of which are produced only
    // by RecordCurrencyExchangeUseCase. Recording it here would create an
    // orphan inflow (cash from nothing), so reject it outright.
    if (type == CashTransactionType.currencyExchangeIn) {
      throw ArgumentError.value(
        type,
        'type',
        'currencyExchangeIn must be recorded through '
            'RecordCurrencyExchangeUseCase, not addCashTransaction — a '
            'destination exchange inflow requires a matching exchange-out '
            'consumption.',
      );
    }

    DataIntegrity.requireCashTransactionInput(
      tripId: tripId,
      amount: amount,
      currencyCode: currencyCode,
      allowZeroAmount: type == CashTransactionType.initialCash,
    );
    await _assertTripExists(tripId);

    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final transactionId = _uuid.v4();
    final lot = _buildInflowLot(
      lotId: _uuid.v4(),
      transactionId: transactionId,
      tripId: tripId,
      type: type,
      amount: amount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: homeCurrencyAmount,
      homeCurrencyCode: homeCurrencyCode,
      note: note,
      createdAt: createdAt,
    );
    final transaction = CashTransaction.create(
      id: transactionId,
      tripId: tripId,
      type: type,
      amount: amount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: homeCurrencyAmount,
      homeCurrencyCode: homeCurrencyCode,
      note: note,
      createdAt: createdAt,
      lotId: lot?.id,
    );

    final signedAmount = type.signedDelta(amount);

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      // Lot first: cash_transactions.lot_id carries a FK to cash_lots(id).
      if (lot != null) {
        await txn.insert(
          AppDatabase.cashLotsTable,
          lot.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await _insertTransaction(txn, transaction);
      await _applyBalanceDelta(
        txn,
        tripId: tripId,
        currencyCode: normalizedCurrency,
        delta: signedAmount,
        updatedAt: transaction.createdAt,
      );
    });
  }

  /// Builds the FIFO lot backing a manual cash **inflow**, or `null` when the
  /// transaction must not create a lot (outflows and zero amounts).
  ///
  /// The basis columns follow the all-or-nothing schema contract: they are set
  /// only when a positive home amount and a home currency are both provided.
  CashLot? _buildInflowLot({
    required String lotId,
    required String transactionId,
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) {
    if (amount <= 0 || type.signedDelta(amount) <= 0) {
      return null;
    }

    final String sourceType;
    switch (type) {
      case CashTransactionType.initialCash:
        sourceType = 'initial_cash';
      case CashTransactionType.manualAdjustment:
        sourceType = 'manual_adjustment';
      case CashTransactionType.atmWithdrawal:
        sourceType = 'atm_withdrawal';
      case CashTransactionType.currencyExchangeIn:
        sourceType = 'exchange_in';
      case CashTransactionType.cashRefund:
        sourceType = 'cash_refund';
      case CashTransactionType.currencyExchangeOut:
      case CashTransactionType.cashExpenseDeduction:
        return null;
    }

    final normalizedHomeCode = homeCurrencyCode?.trim().toUpperCase();
    final hasBasis = homeCurrencyAmount != null &&
        homeCurrencyAmount > 0 &&
        normalizedHomeCode != null &&
        normalizedHomeCode.isNotEmpty;

    return CashLot.create(
      id: lotId,
      tripId: tripId,
      sourceType: sourceType,
      sourceRefType: 'cash_transaction',
      sourceRefId: transactionId,
      currencyCode: currencyCode,
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: hasBasis ? homeCurrencyAmount : null,
      homeCurrencyCode: hasBasis ? normalizedHomeCode : null,
      effectiveRate: hasBasis ? homeCurrencyAmount / amount : null,
      createdAt: createdAt,
      note: note,
    );
  }

  /// Inserts an ATM withdrawal [CashTransaction] row (with [lotId] set) and
  /// applies the balance delta, all inside the caller's [txn].
  ///
  /// Called by [RecordAtmWithdrawalUseCase] to participate in its outer
  /// atomic transaction.  The returned [CashTransaction] has the assigned ID.
  Future<CashTransaction> recordAtmInflow({
    required DatabaseExecutor txn,
    required String tripId,
    required String lotId,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      type: CashTransactionType.atmWithdrawal,
      amount: amount,
      currencyCode: currencyCode,
      homeCurrencyAmount: homeCurrencyAmount,
      homeCurrencyCode: homeCurrencyCode,
      note: note,
      createdAt: createdAt,
      lotId: lotId,
    );
    await _insertTransaction(txn, transaction);
    await _applyBalanceDelta(
      txn,
      tripId: tripId,
      currencyCode: transaction.currencyCode,
      delta: CashTransactionType.atmWithdrawal.signedDelta(amount),
      updatedAt: transaction.createdAt,
    );
    return transaction;
  }

  /// Inserts a [CashTransactionType.cashRefund] row (with optional [lotId] set)
  /// and applies `+amount` to [currencyCode] balance, all inside the caller's
  /// [txn].
  ///
  /// Called by [RecordRefundUseCase] to participate in its outer atomic
  /// transaction.
  Future<CashTransaction> recordCashRefundInflow({
    required DatabaseExecutor txn,
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? lotId,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      expenseId: expenseId,
      type: CashTransactionType.cashRefund,
      amount: amount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: homeCurrencyAmount,
      homeCurrencyCode: homeCurrencyCode,
      note: note,
      createdAt: createdAt,
      lotId: lotId,
    );
    await _insertTransaction(txn, transaction);
    await _applyBalanceDelta(
      txn,
      tripId: tripId,
      currencyCode: normalizedCurrency,
      delta: CashTransactionType.cashRefund.signedDelta(amount),
      updatedAt: transaction.createdAt,
    );
    return transaction;
  }

  /// Inserts a [CashTransactionType.currencyExchangeOut] row and applies
  /// `-fromAmount` to [fromCurrencyCode] balance, all inside the caller's [txn].
  ///
  /// Called by [RecordCurrencyExchangeUseCase] to participate in its outer
  /// atomic transaction.
  Future<CashTransaction> recordCurrencyExchangeOutflow({
    required DatabaseExecutor txn,
    required String tripId,
    required double fromAmount,
    required String fromCurrencyCode,
    String? exchangeId,
    String? note,
    DateTime? createdAt,
  }) async {
    final normalizedCurrency = fromCurrencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      type: CashTransactionType.currencyExchangeOut,
      amount: fromAmount,
      currencyCode: normalizedCurrency,
      note: note,
      createdAt: createdAt,
      exchangeId: exchangeId,
    );
    await _insertTransaction(txn, transaction);
    await _applyBalanceDelta(
      txn,
      tripId: tripId,
      currencyCode: normalizedCurrency,
      delta: CashTransactionType.currencyExchangeOut.signedDelta(fromAmount),
      updatedAt: transaction.createdAt,
    );
    return transaction;
  }

  /// Inserts a [CashTransactionType.currencyExchangeIn] row (with [toLotId] set)
  /// and applies `+toAmount` to [toCurrencyCode] balance, all inside the
  /// caller's [txn].
  ///
  /// Called by [RecordCurrencyExchangeUseCase] to participate in its outer
  /// atomic transaction.
  Future<CashTransaction> recordCurrencyExchangeInflow({
    required DatabaseExecutor txn,
    required String tripId,
    required String toLotId,
    required double toAmount,
    required String toCurrencyCode,
    String? exchangeId,
    String? note,
    DateTime? createdAt,
  }) async {
    final normalizedCurrency = toCurrencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      type: CashTransactionType.currencyExchangeIn,
      amount: toAmount,
      currencyCode: normalizedCurrency,
      note: note,
      createdAt: createdAt,
      lotId: toLotId,
      exchangeId: exchangeId,
    );
    await _insertTransaction(txn, transaction);
    await _applyBalanceDelta(
      txn,
      tripId: tripId,
      currencyCode: normalizedCurrency,
      delta: CashTransactionType.currencyExchangeIn.signedDelta(toAmount),
      updatedAt: transaction.createdAt,
    );
    return transaction;
  }

  /// Reverses the two `currency_exchange_out` / `currency_exchange_in` cash
  /// transactions linked to [exchangeId] and restores [trip_cash_balances],
  /// all inside the caller's [txn].
  ///
  /// Original effects undone:
  /// * `exchange_out`: source balance was decreased by `fromAmount` → restored.
  /// * `exchange_in`:  destination balance was increased by `toAmount` → removed.
  ///
  /// Idempotency-safe: only rows with `is_reversed = 0` are touched, so a
  /// double call is a no-op for already-reversed rows. Throws [StateError] when
  /// no active exchange transactions are found (the linkage is required —
  /// `RecordCurrencyExchangeUseCase` always sets `exchange_id`).
  Future<void> reverseCurrencyExchangeTransactionsInTxn(
    DatabaseExecutor txn, {
    required String exchangeId,
  }) async {
    final now = DateTime.now().toUtc();
    final rows = await txn.query(
      AppDatabase.cashTransactionsTable,
      where: 'exchange_id = ? AND is_reversed = 0 AND type IN (?, ?)',
      whereArgs: [
        exchangeId,
        CashTransactionType.currencyExchangeOut.value,
        CashTransactionType.currencyExchangeIn.value,
      ],
    );

    if (rows.isEmpty) {
      throw StateError(
        'No active exchange cash transactions found for exchange '
        '$exchangeId — cannot reverse.',
      );
    }

    for (final row in rows) {
      final transaction = CashTransaction.fromMap(row);
      await txn.update(
        AppDatabase.cashTransactionsTable,
        {
          'is_reversed': 1,
          'reversed_at': now.toIso8601String(),
        },
        where: 'id = ? AND is_reversed = 0',
        whereArgs: [transaction.id],
      );
      // Undo the original signed delta (out restores +fromAmount to the source
      // currency; in removes +toAmount from the destination currency).
      final reversalDelta = -transaction.type.signedDelta(transaction.amount);
      await _applyBalanceDelta(
        txn,
        tripId: transaction.tripId,
        currencyCode: transaction.currencyCode,
        delta: reversalDelta,
        updatedAt: now,
      );
    }
  }

  Future<void> reverseManualCashTransaction({
    required CashTransaction transaction,
  }) async {
    if (!_isEditableManualTransaction(transaction)) {
      throw ArgumentError('Only manual cash transactions can be reversed.');
    }

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _reverseManualCashTransactionInTxn(
        txn,
        transaction: transaction,
      );
    });
  }

  Future<void> updateManualCashTransaction({
    required CashTransaction existingTransaction,
    required CashTransactionType nextType,
    required double nextAmount,
    required String nextCurrencyCode,
    double? nextHomeCurrencyAmount,
    String? nextHomeCurrencyCode,
    String? nextNote,
    DateTime? nextCreatedAt,
  }) async {
    if (!_isEditableManualTransaction(existingTransaction)) {
      throw ArgumentError('Only manual cash transactions can be updated.');
    }

    // Defense in depth: editing must never re-type a manual row into an
    // exchange row. Exchange in/out rows are one half of a two-sided,
    // lot-consuming exchange owned by RecordCurrencyExchangeUseCase; minting one
    // here (reverse + recreate with an exchange nextType) would orphan the lot
    // and break balance conservation. Reject the conversion before any write.
    if (nextType == CashTransactionType.currencyExchangeIn ||
        nextType == CashTransactionType.currencyExchangeOut) {
      throw ArgumentError.value(
        nextType,
        'nextType',
        'A manual cash transaction cannot be converted into a currency '
            'exchange — exchanges are recorded only through '
            'RecordCurrencyExchangeUseCase.',
      );
    }

    DataIntegrity.requireCashTransactionInput(
      tripId: existingTransaction.tripId,
      amount: nextAmount,
      currencyCode: nextCurrencyCode,
    );

    final normalizedCurrency = nextCurrencyCode.trim().toUpperCase();
    final replacementTransactionId = _uuid.v4();
    // Reverse + recreate keeps the lot ledger consistent: the old inflow lot
    // is reversed (guarded against consumed cash) and a fresh lot backs the
    // replacement transaction.
    final replacementLot = _buildInflowLot(
      lotId: _uuid.v4(),
      transactionId: replacementTransactionId,
      tripId: existingTransaction.tripId,
      type: nextType,
      amount: nextAmount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: nextHomeCurrencyAmount,
      homeCurrencyCode: nextHomeCurrencyCode,
      note: nextNote,
      createdAt: nextCreatedAt,
    );
    final replacementTransaction = CashTransaction.create(
      id: replacementTransactionId,
      tripId: existingTransaction.tripId,
      type: nextType,
      amount: nextAmount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: nextHomeCurrencyAmount,
      homeCurrencyCode: nextHomeCurrencyCode,
      note: nextNote,
      createdAt: nextCreatedAt,
      lotId: replacementLot?.id,
    );

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _reverseManualCashTransactionInTxn(
        txn,
        transaction: existingTransaction,
      );
      // Lot first: cash_transactions.lot_id carries a FK to cash_lots(id).
      if (replacementLot != null) {
        await txn.insert(
          AppDatabase.cashLotsTable,
          replacementLot.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await _insertTransaction(txn, replacementTransaction);
      await _applyBalanceDelta(
        txn,
        tripId: replacementTransaction.tripId,
        currencyCode: replacementTransaction.currencyCode,
        delta: nextType.signedDelta(nextAmount),
        updatedAt: replacementTransaction.createdAt,
      );
    });
  }

  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
    DatabaseExecutor? txn,
  }) async {
    DataIntegrity.requireCashTransactionInput(
      tripId: tripId,
      amount: amount,
      currencyCode: currencyCode,
    );

    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      expenseId: expenseId,
      type: CashTransactionType.cashExpenseDeduction,
      amount: amount,
      currencyCode: normalizedCurrency,
      note: note,
    );

    Future<CashExpenseDeductionResult> deduct(DatabaseExecutor executor) async {
      await _assertTripExists(tripId, executor: executor);

      final currentBalance = await _getCurrentBalance(
        executor,
        tripId: tripId,
        currencyCode: normalizedCurrency,
      );
      final wasInsufficient = currentBalance < amount;
      final nextBalance = currentBalance - amount;

      await _insertTransaction(executor, transaction);
      await _upsertBalance(
        executor,
        tripId: tripId,
        currencyCode: normalizedCurrency,
        nextBalance: nextBalance,
        updatedAt: transaction.createdAt,
      );

      return CashExpenseDeductionResult(
        wasInsufficientBeforeDeduction: wasInsufficient,
        balanceAfterDeduction: nextBalance,
      );
    }

    if (txn != null) {
      return deduct(txn);
    }

    final db = await _appDatabase.database;
    return db.transaction(deduct);
  }

  Future<void> syncExpenseCashImpact({
    required Expense? previousExpense,
    required Expense nextExpense,
  }) async {
    final oldExpense = previousExpense;
    final oldIsCash = previousExpense != null && _isCashExpense(previousExpense);
    final newIsCash = _isCashExpense(nextExpense);

    if (!oldIsCash && !newIsCash) {
      return;
    }

    if (oldIsCash && !newIsCash) {
      await reverseCashExpenseDeduction(
        tripId: oldExpense!.tripId,
        expenseId: oldExpense.id,
        fallbackExpense: oldExpense,
      );
      return;
    }

    if (!oldIsCash && newIsCash) {
      await recordCashExpenseDeduction(
        tripId: nextExpense.tripId,
        expenseId: nextExpense.id,
        amount: nextExpense.transactionAmount,
        currencyCode: nextExpense.transactionCurrency,
        note: nextExpense.note,
      );
      return;
    }

    final amountChanged =
      (oldExpense!.transactionAmount - nextExpense.transactionAmount).abs() > 0.000001;
    final currencyChanged =
      oldExpense.transactionCurrency.trim().toUpperCase() !=
            nextExpense.transactionCurrency.trim().toUpperCase();

    if (!amountChanged && !currencyChanged) {
      return;
    }

    await reverseCashExpenseDeduction(
      tripId: oldExpense.tripId,
      expenseId: oldExpense.id,
      fallbackExpense: oldExpense,
    );
    await recordCashExpenseDeduction(
      tripId: nextExpense.tripId,
      expenseId: nextExpense.id,
      amount: nextExpense.transactionAmount,
      currencyCode: nextExpense.transactionCurrency,
      note: nextExpense.note,
    );
  }

  Future<void> restoreCashForDeletedExpense(Expense expense) async {
    if (!_isCashExpense(expense)) {
      return;
    }

    await reverseCashExpenseDeduction(
      tripId: expense.tripId,
      expenseId: expense.id,
      fallbackExpense: expense,
    );
  }

  Future<bool> reverseCashExpenseDeduction({
    required String tripId,
    required String expenseId,
    Expense? fallbackExpense,
  }) async {
    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      return _reverseCashExpenseDeductionBody(
        txn,
        tripId: tripId,
        expenseId: expenseId,
        fallbackExpense: fallbackExpense,
      );
    });
  }

  /// Reverses the active [cash_transactions] deduction for [expenseId] and
  /// restores [trip_cash_balances], using the caller-supplied [txn] so this
  /// participates in an outer transaction.
  ///
  /// Returns [true] when a matching deduction was found and reversed.
  Future<bool> reverseCashExpenseDeductionInTxn(
    DatabaseExecutor txn, {
    required String tripId,
    required String expenseId,
  }) {
    return _reverseCashExpenseDeductionBody(
      txn,
      tripId: tripId,
      expenseId: expenseId,
    );
  }

  Future<bool> _reverseCashExpenseDeductionBody(
    DatabaseExecutor txn, {
    required String tripId,
    required String expenseId,
    Expense? fallbackExpense,
  }) async {
    Map<String, Object?>? deduction = await _findActiveDeductionByExpenseId(
      txn,
      tripId: tripId,
      expenseId: expenseId,
    );

    deduction ??= await _findFallbackActiveDeduction(txn, expenseId: expenseId, fallbackExpense: fallbackExpense);

    if (deduction == null) {
      return false;
    }

    final deductionAmount = (deduction['amount'] as num).toDouble();
    final deductionCurrency = (deduction['currency_code'] as String).trim().toUpperCase();
    final now = DateTime.now().toUtc();

    await txn.update(
      AppDatabase.cashTransactionsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
        if ((deduction['expense_id'] as String?) == null) 'expense_id': expenseId,
      },
      where: 'id = ?',
      whereArgs: [deduction['id']],
    );

    await _applyBalanceDelta(
      txn,
      tripId: tripId,
      currencyCode: deductionCurrency,
      delta: deductionAmount,
      updatedAt: now,
    );

    return true;
  }

  Future<Map<String, Object?>?> _findActiveDeductionByExpenseId(
    DatabaseExecutor txn, {
    required String tripId,
    required String expenseId,
  }) async {
    final rows = await txn.query(
      AppDatabase.cashTransactionsTable,
      where: 'trip_id = ? AND expense_id = ? AND type = ? AND is_reversed = 0',
      whereArgs: [tripId, expenseId, CashTransactionType.cashExpenseDeduction.value],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  Future<Map<String, Object?>?> _findFallbackActiveDeduction(
    DatabaseExecutor txn, {
    required String expenseId,
    required Expense? fallbackExpense,
  }) async {
    if (fallbackExpense == null) {
      return null;
    }

    final whereParts = <String>[
      'trip_id = ?',
      'type = ?',
      'is_reversed = 0',
      'currency_code = ?',
      'ABS(amount - ?) < 0.000001',
      'expense_id IS NULL',
    ];
    final whereArgs = <Object?>[
      fallbackExpense.tripId,
      CashTransactionType.cashExpenseDeduction.value,
      fallbackExpense.transactionCurrency.trim().toUpperCase(),
      fallbackExpense.transactionAmount,
    ];

    if (fallbackExpense.note != null && fallbackExpense.note!.trim().isNotEmpty) {
      whereParts.add('note = ?');
      whereArgs.add(fallbackExpense.note!.trim());
    }

    final rows = await txn.query(
      AppDatabase.cashTransactionsTable,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first;
  }

  Future<void> _reverseManualCashTransactionInTxn(
    DatabaseExecutor txn, {
    required CashTransaction transaction,
  }) async {
    final now = DateTime.now().toUtc();

    // Resolve the linked inflow lot (if any) from the stored row, not the
    // caller-supplied object, so stale in-memory copies cannot skip the lot.
    final storedRows = await txn.query(
      AppDatabase.cashTransactionsTable,
      columns: ['lot_id'],
      where: 'id = ? AND is_reversed = 0',
      whereArgs: [transaction.id],
      limit: 1,
    );
    if (storedRows.isEmpty) {
      throw StateError('Transaction already reversed or not found.');
    }
    final lotId = storedRows.first['lot_id'] as String?;

    // Reverse the linked lot first. A lot whose cash was already (partially)
    // spent or exchanged cannot be reversed — that would orphan consumptions
    // and let FIFO overdraw the wallet.
    if (lotId != null) {
      final lotRows = await txn.query(
        AppDatabase.cashLotsTable,
        where: 'id = ? AND is_reversed = 0',
        whereArgs: [lotId],
        limit: 1,
      );
      if (lotRows.isNotEmpty) {
        final lot = CashLot.fromMap(lotRows.first);
        const epsilon = 1e-9;
        if (lot.originalAmount - lot.remainingAmount > epsilon) {
          throw StateError(
            'Cash from this transaction has already been spent; '
            'reverse the consuming expenses/exchanges first.',
          );
        }
        await txn.update(
          AppDatabase.cashLotsTable,
          {
            'is_reversed': 1,
            'reversed_at': now.toIso8601String(),
            'is_fully_consumed': 1,
            'remaining_amount': 0.0,
          },
          where: 'id = ?',
          whereArgs: [lotId],
        );
      }
    }

    final affected = await txn.update(
      AppDatabase.cashTransactionsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
      },
      where: 'id = ? AND is_reversed = 0',
      whereArgs: [transaction.id],
    );

    if (affected == 0) {
      throw StateError('Transaction already reversed or not found.');
    }

    final reversalDelta = -transaction.type.signedDelta(transaction.amount);
    await _applyBalanceDelta(
      txn,
      tripId: transaction.tripId,
      currencyCode: transaction.currencyCode,
      delta: reversalDelta,
      updatedAt: now,
    );
  }

  Future<void> _insertTransaction(
    DatabaseExecutor txn,
    CashTransaction transaction,
  ) {
    return txn.insert(
      AppDatabase.cashTransactionsTable,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> _applyBalanceDelta(
    DatabaseExecutor txn, {
    required String tripId,
    required String currencyCode,
    required double delta,
    required DateTime updatedAt,
  }) async {
    final current = await _getCurrentBalance(
      txn,
      tripId: tripId,
      currencyCode: currencyCode,
    );
    final nextBalance = current + delta;
    await _upsertBalance(
      txn,
      tripId: tripId,
      currencyCode: currencyCode,
      nextBalance: nextBalance,
      updatedAt: updatedAt,
    );
  }

  Future<double> _getCurrentBalance(
    DatabaseExecutor txn, {
    required String tripId,
    required String currencyCode,
  }) async {
    final rows = await txn.query(
      AppDatabase.tripCashBalancesTable,
      columns: ['balance_amount'],
      where: 'trip_id = ? AND currency_code = ?',
      whereArgs: [tripId, currencyCode],
      limit: 1,
    );

    if (rows.isEmpty) {
      return 0;
    }

    return (rows.first['balance_amount'] as num).toDouble();
  }

  Future<void> _upsertBalance(
    DatabaseExecutor txn, {
    required String tripId,
    required String currencyCode,
    required double nextBalance,
    required DateTime updatedAt,
  }) async {
    final payload = {
      'trip_id': tripId,
      'currency_code': currencyCode,
      'balance_amount': nextBalance,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };

    final affected = await txn.update(
      AppDatabase.tripCashBalancesTable,
      payload,
      where: 'trip_id = ? AND currency_code = ?',
      whereArgs: [tripId, currencyCode],
    );

    if (affected == 0) {
      await txn.insert(
        AppDatabase.tripCashBalancesTable,
        payload,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  bool _isCashExpense(Expense expense) {
    return isCashExpensePayment(
      paymentMethod: expense.paymentMethod,
      paymentChannel: expense.paymentChannel,
    );
  }

  /// Returns the weighted-average effective cash rate for [transactionCurrencyCode]
  /// → [homeCurrencyCode], derived from all non-reversed inflow transactions that
  /// have a [CashTransaction.homeCurrencyAmount] recorded.
  ///
  /// Returns `null` when no usable inflow data exists yet.
  Future<double?> getEffectiveCashRate({
    required String tripId,
    required String transactionCurrencyCode,
    required String homeCurrencyCode,
  }) async {
    final db = await _appDatabase.database;
    final normalizedTxCurrency = transactionCurrencyCode.trim().toUpperCase();
    final normalizedHomeCurrency = homeCurrencyCode.trim().toUpperCase();

    final inflowTypeValues = [
      CashTransactionType.initialCash.value,
      CashTransactionType.atmWithdrawal.value,
      CashTransactionType.currencyExchangeIn.value,
      CashTransactionType.manualAdjustment.value,
    ];
    final placeholders = inflowTypeValues.map((_) => '?').join(', ');

    final rows = await db.rawQuery(
      '''
      SELECT amount, home_currency_amount
      FROM ${AppDatabase.cashTransactionsTable}
      WHERE trip_id = ?
        AND currency_code = ?
        AND home_currency_code = ?
        AND is_reversed = 0
        AND home_currency_amount IS NOT NULL
        AND home_currency_amount > 0
        AND type IN ($placeholders)
      ''',
      [tripId, normalizedTxCurrency, normalizedHomeCurrency, ...inflowTypeValues],
    );

    return CashEffectiveRateCalculator.calculate(rows);
  }

  Future<void> _assertTripExists(
    String tripId, {
    DatabaseExecutor? executor,
  }) async {
    final db = executor ?? await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tripsTable,
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const DataIntegrityException('tripNotFound');
    }
  }

  bool _isEditableManualTransaction(CashTransaction transaction) {
    if (transaction.isReversed || transaction.expenseId != null) {
      return false;
    }

    switch (transaction.type) {
      case CashTransactionType.initialCash:
      case CashTransactionType.atmWithdrawal:
      case CashTransactionType.manualAdjustment:
        return true;
      // Exchange rows (in/out) must never be edited or reversed through the
      // manual cash-transaction path. They are one half of a two-sided,
      // lot-consuming exchange owned by RecordCurrencyExchangeUseCase; touching
      // one side here would orphan lots and break balance conservation. This
      // guard makes updateManualCashTransaction and reverseManualCashTransaction
      // reject them even if a future UI re-exposes the action (defense in depth).
      case CashTransactionType.currencyExchangeIn:
      case CashTransactionType.currencyExchangeOut:
      case CashTransactionType.cashExpenseDeduction:
      case CashTransactionType.cashRefund:
        return false;
    }
  }
}
