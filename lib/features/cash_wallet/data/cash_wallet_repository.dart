import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/domain/expense.dart';
import '../domain/cash_transaction.dart';
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

  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    String? note,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
      type: type,
      amount: amount,
      currencyCode: normalizedCurrency,
      note: note,
    );

    final signedAmount = _signedDelta(type, amount);

    final db = await _appDatabase.database;
    await db.transaction((txn) async {
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

  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
  }) async {
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

    final db = await _appDatabase.database;
    return db.transaction((txn) async {
      final currentBalance = await _getCurrentBalance(
        txn,
        tripId: tripId,
        currencyCode: normalizedCurrency,
      );
      final wasInsufficient = currentBalance < amount;
      final nextBalance = currentBalance - amount;

      await _insertTransaction(txn, transaction);
      await _upsertBalance(
        txn,
        tripId: tripId,
        currencyCode: normalizedCurrency,
        nextBalance: nextBalance,
        updatedAt: transaction.createdAt,
      );

      return CashExpenseDeductionResult(
        wasInsufficientBeforeDeduction: wasInsufficient,
        balanceAfterDeduction: nextBalance,
      );
    });
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
    });
  }

  Future<Map<String, Object?>?> _findActiveDeductionByExpenseId(
    Transaction txn, {
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
    Transaction txn, {
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

  Future<void> _insertTransaction(
    Transaction txn,
    CashTransaction transaction,
  ) {
    return txn.insert(
      AppDatabase.cashTransactionsTable,
      transaction.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<void> _applyBalanceDelta(
    Transaction txn, {
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
    Transaction txn, {
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
    Transaction txn, {
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

  double _signedDelta(CashTransactionType type, double amount) {
    switch (type) {
      case CashTransactionType.initialCash:
      case CashTransactionType.atmWithdrawal:
      case CashTransactionType.currencyExchangeIn:
        return amount;
      case CashTransactionType.currencyExchangeOut:
      case CashTransactionType.cashExpenseDeduction:
        return -amount;
      case CashTransactionType.manualAdjustment:
        return amount;
    }
  }

  bool _isCashExpense(Expense expense) {
    final paymentMethod = expense.paymentMethod.trim().toLowerCase();
    final paymentChannel = expense.paymentChannel?.trim().toLowerCase();
    return paymentMethod == 'cash' || paymentChannel == 'cash';
  }
}
