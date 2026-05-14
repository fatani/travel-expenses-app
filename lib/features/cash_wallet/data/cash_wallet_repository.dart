import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
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
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashTransactionsTable,
      where: 'trip_id = ?',
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
    required double amount,
    required String currencyCode,
    String? note,
  }) async {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    final transaction = CashTransaction.create(
      id: _uuid.v4(),
      tripId: tripId,
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
}
