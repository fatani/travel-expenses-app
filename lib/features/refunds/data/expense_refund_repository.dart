import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/integrity/data_integrity.dart';
import '../../cash_wallet/domain/cash_transaction.dart';
import '../../expenses/domain/expense.dart';
import '../domain/expense_refund.dart';
import '../domain/refund_destination.dart';

class RefundOverLimitException implements Exception {
  const RefundOverLimitException({
    required this.requested,
    required this.existing,
    required this.limit,
  });

  final double requested;
  final double existing;
  final double limit;

  @override
  String toString() =>
      'RefundOverLimitException: requested=$requested existing=$existing limit=$limit';
}

class ExpenseRefundRepository {
  ExpenseRefundRepository(this._appDatabase, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  Future<ExpenseRefund> createCardRefund({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    double? homeAmount,
    String? homeCurrency,
    String? note,
    DateTime? createdAt,
    Expense? linkedExpense,
  }) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    DataIntegrity.requirePositiveAmount(amount);
    DataIntegrity.requireValidCurrencyCode(currencyCode);

    final derived = _deriveHomeAmount(
      callerHomeAmount: homeAmount,
      callerHomeCurrency: homeCurrency,
      refundAmount: amount,
      linkedExpense: linkedExpense,
    );

    final refund = ExpenseRefund.create(
      id: _uuid.v4(),
      tripId: tripId,
      expenseId: expenseId,
      amount: amount,
      currencyCode: currencyCode,
      homeAmount: derived.homeAmount,
      homeCurrency: derived.homeCurrency,
      destination: RefundDestination.card,
      note: note,
      createdAt: createdAt,
    );

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _assertTripExists(txn, tripId);
      await _assertOverRefundGuard(
        txn,
        expenseId: expenseId,
        newHomeAmount: refund.homeAmount,
        linkedExpense: linkedExpense,
      );
      await _insertRefund(txn, refund);
    });

    return refund;
  }

  Future<ExpenseRefund> createCashRefund({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    double? homeAmount,
    String? homeCurrency,
    String? note,
    DateTime? createdAt,
    Expense? linkedExpense,
  }) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    DataIntegrity.requirePositiveAmount(amount);
    DataIntegrity.requireValidCurrencyCode(currencyCode);

    final derived = _deriveHomeAmount(
      callerHomeAmount: homeAmount,
      callerHomeCurrency: homeCurrency,
      refundAmount: amount,
      linkedExpense: linkedExpense,
    );

    final normalizedCurrency = currencyCode.trim().toUpperCase();

    final refund = ExpenseRefund.create(
      id: _uuid.v4(),
      tripId: tripId,
      expenseId: expenseId,
      amount: amount,
      currencyCode: normalizedCurrency,
      homeAmount: derived.homeAmount,
      homeCurrency: derived.homeCurrency,
      destination: RefundDestination.cash,
      note: note,
      createdAt: createdAt,
    );

    final cashTx = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      expenseId: expenseId,
      type: CashTransactionType.cashRefund,
      amount: amount,
      currencyCode: normalizedCurrency,
      homeCurrencyAmount: derived.homeAmount,
      homeCurrencyCode: derived.homeCurrency,
      note: note,
      createdAt: createdAt,
    );

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await _assertTripExists(txn, tripId);
      await _assertOverRefundGuard(
        txn,
        expenseId: expenseId,
        newHomeAmount: refund.homeAmount,
        linkedExpense: linkedExpense,
      );
      await _insertRefund(txn, refund);
      await _insertCashTransaction(txn, cashTx);
      await _applyBalanceDelta(
        txn,
        tripId: tripId,
        currencyCode: normalizedCurrency,
        delta: CashTransactionType.cashRefund.signedDelta(amount),
        updatedAt: refund.createdAt,
      );
    });

    return refund;
  }

  // ---------------------------------------------------------------------------
  // Reverse
  // ---------------------------------------------------------------------------

  Future<void> reverseCardRefund(ExpenseRefund refund) async {
    if (refund.isReversed) {
      throw StateError('Refund is already reversed: ${refund.id}');
    }
    if (refund.destination != RefundDestination.card) {
      throw ArgumentError('reverseCardRefund called on non-card refund');
    }

    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final affected = await db.update(
      AppDatabase.expenseRefundsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
      },
      where: 'id = ? AND is_reversed = 0',
      whereArgs: [refund.id],
    );
    if (affected == 0) {
      throw StateError('Refund not found or already reversed: ${refund.id}');
    }
  }

  Future<void> reverseCashRefund(ExpenseRefund refund) async {
    if (refund.isReversed) {
      throw StateError('Refund is already reversed: ${refund.id}');
    }
    if (refund.destination != RefundDestination.cash) {
      throw ArgumentError('reverseCashRefund called on non-cash refund');
    }

    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    await db.transaction((txn) async {
      final affected = await txn.update(
        AppDatabase.expenseRefundsTable,
        {
          'is_reversed': 1,
          'reversed_at': now.toIso8601String(),
        },
        where: 'id = ? AND is_reversed = 0',
        whereArgs: [refund.id],
      );
      if (affected == 0) {
        throw StateError('Refund not found or already reversed: ${refund.id}');
      }

      final cashTxRow = await _findActiveCashRefundTransaction(
        txn,
        tripId: refund.tripId,
        refundExpenseId: refund.expenseId,
        amount: refund.amount,
        currencyCode: refund.currencyCode,
      );
      if (cashTxRow != null) {
        await txn.update(
          AppDatabase.cashTransactionsTable,
          {
            'is_reversed': 1,
            'reversed_at': now.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [cashTxRow['id']],
        );

        final txAmount = (cashTxRow['amount'] as num).toDouble();
        final txCurrency = (cashTxRow['currency_code'] as String).trim().toUpperCase();
        await _applyBalanceDelta(
          txn,
          tripId: refund.tripId,
          currencyCode: txCurrency,
          delta: -CashTransactionType.cashRefund.signedDelta(txAmount),
          updatedAt: now,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  Future<List<ExpenseRefund>> getActiveRefundsByTrip(String tripId) async {
    DataIntegrity.requireNonEmptyTripId(tripId);
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expenseRefundsTable,
      where: 'trip_id = ? AND is_reversed = 0',
      whereArgs: [tripId],
      orderBy: 'created_at DESC',
    );
    return rows.map(ExpenseRefund.fromMap).toList();
  }

  Future<List<ExpenseRefund>> getActiveRefundsByExpense(String expenseId) async {
    DataIntegrity.requireNonEmptyId(expenseId, field: 'expenseId');
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.expenseRefundsTable,
      where: 'expense_id = ? AND is_reversed = 0',
      whereArgs: [expenseId],
      orderBy: 'created_at ASC',
    );
    return rows.map(ExpenseRefund.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // homeAmount derivation (Section 1.4 of spec)
  // ---------------------------------------------------------------------------

  static ({double? homeAmount, String? homeCurrency}) _deriveHomeAmount({
    required double? callerHomeAmount,
    required String? callerHomeCurrency,
    required double refundAmount,
    required Expense? linkedExpense,
  }) {
    if (callerHomeAmount != null) {
      return (homeAmount: callerHomeAmount, homeCurrency: callerHomeCurrency);
    }

    if (linkedExpense == null) {
      return (homeAmount: null, homeCurrency: null);
    }

    final expense = linkedExpense;
    final homeCurrency = expense.homeCurrency;
    if (homeCurrency == null) {
      return (homeAmount: null, homeCurrency: null);
    }

    final rate = expense.conversionRate;
    if (rate != null && rate > 0) {
      return (homeAmount: refundAmount * rate, homeCurrency: homeCurrency);
    }

    final convertedHome = expense.convertedHomeAmount;
    final txAmount = expense.transactionAmount;
    if (convertedHome != null && txAmount > 0) {
      return (
        homeAmount: (refundAmount / txAmount) * convertedHome,
        homeCurrency: homeCurrency,
      );
    }

    return (homeAmount: null, homeCurrency: null);
  }

  // ---------------------------------------------------------------------------
  // Over-refund guard (Section 1.3, Invariant 5 of spec)
  // ---------------------------------------------------------------------------

  Future<void> _assertOverRefundGuard(
    DatabaseExecutor txn, {
    required String? expenseId,
    required double? newHomeAmount,
    required Expense? linkedExpense,
  }) async {
    if (expenseId == null) return;
    if (newHomeAmount == null) return;

    final expenseHomeAmount = linkedExpense?.convertedHomeAmount;
    if (expenseHomeAmount == null) return;

    final expenseHomeCurrency = linkedExpense?.homeCurrency;
    if (expenseHomeCurrency == null) return;

    final rows = await txn.rawQuery(
      '''
      SELECT COALESCE(SUM(home_amount), 0) AS total
      FROM ${AppDatabase.expenseRefundsTable}
      WHERE expense_id = ?
        AND is_reversed = 0
        AND home_currency = ?
        AND home_amount IS NOT NULL
      ''',
      [expenseId, expenseHomeCurrency],
    );

    final existing = ((rows.first['total'] as num?) ?? 0).toDouble();

    if (existing + newHomeAmount > expenseHomeAmount + 0.000001) {
      throw RefundOverLimitException(
        requested: newHomeAmount,
        existing: existing,
        limit: expenseHomeAmount,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _insertRefund(DatabaseExecutor txn, ExpenseRefund refund) {
    return txn.insert(
      AppDatabase.expenseRefundsTable,
      refund.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> _insertCashTransaction(
    DatabaseExecutor txn,
    CashTransaction tx,
  ) {
    return txn.insert(
      AppDatabase.cashTransactionsTable,
      tx.toMap(),
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
    final rows = await txn.query(
      AppDatabase.tripCashBalancesTable,
      columns: ['balance_amount'],
      where: 'trip_id = ? AND currency_code = ?',
      whereArgs: [tripId, currencyCode],
      limit: 1,
    );

    final current =
        rows.isEmpty ? 0.0 : (rows.first['balance_amount'] as num).toDouble();
    final next = current + delta;

    final payload = {
      'trip_id': tripId,
      'currency_code': currencyCode,
      'balance_amount': next,
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

  Future<Map<String, Object?>?> _findActiveCashRefundTransaction(
    DatabaseExecutor txn, {
    required String tripId,
    required String? refundExpenseId,
    required double amount,
    required String currencyCode,
  }) async {
    final whereArgs = <Object?>[
      tripId,
      CashTransactionType.cashRefund.value,
      currencyCode,
      amount,
    ];

    String whereClause =
        'trip_id = ? AND type = ? AND currency_code = ? AND ABS(amount - ?) < 0.000001 AND is_reversed = 0';

    if (refundExpenseId != null) {
      whereClause += ' AND expense_id = ?';
      whereArgs.add(refundExpenseId);
    } else {
      whereClause += ' AND expense_id IS NULL';
    }

    final rows = await txn.query(
      AppDatabase.cashTransactionsTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _assertTripExists(DatabaseExecutor txn, String tripId) async {
    final rows = await txn.query(
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
}
