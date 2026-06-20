import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/cash_lot_consumption.dart';

class CashLotConsumptionRepository {
  CashLotConsumptionRepository(this._appDatabase, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<CashLotConsumption> insertConsumption(
    CashLotConsumption consumption, {
    DatabaseExecutor? txn,
  }) async {
    final entity = consumption.id.isEmpty
        ? CashLotConsumption(
            id: _uuid.v4(),
            lotId: consumption.lotId,
            consumptionType: consumption.consumptionType,
            expenseId: consumption.expenseId,
            exchangeId: consumption.exchangeId,
            consumedAmount: consumption.consumedAmount,
            homeAmount: consumption.homeAmount,
            homeCurrencyCode: consumption.homeCurrencyCode,
            isReversed: consumption.isReversed,
            reversedAt: consumption.reversedAt,
            createdAt: consumption.createdAt,
          )
        : consumption;
    final executor = txn ?? await _appDatabase.database;
    await executor.insert(
      AppDatabase.cashLotConsumptionsTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity;
  }

  Future<List<CashLotConsumption>> getConsumptionsByExpenseId(
    String expenseId,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotConsumptionsTable,
      where: 'expense_id = ?',
      whereArgs: [expenseId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLotConsumption.fromMap).toList();
  }

  Future<List<CashLotConsumption>> getConsumptionsByExchangeId(
    String exchangeId,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotConsumptionsTable,
      where: 'exchange_id = ?',
      whereArgs: [exchangeId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLotConsumption.fromMap).toList();
  }

  Future<List<CashLotConsumption>> getConsumptionsByLotId(
    String lotId,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotConsumptionsTable,
      where: 'lot_id = ?',
      whereArgs: [lotId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLotConsumption.fromMap).toList();
  }

  /// Returns the **active** (not reversed) consumptions that draw from [lotId].
  ///
  /// Used by the exchange undo/correct flow to detect whether a destination lot
  /// has been spent. Pass [txn] to read uncommitted writes inside an outer
  /// transaction (e.g. when re-validating just before reversing).
  Future<List<CashLotConsumption>> getActiveConsumptionsByLotId(
    String lotId, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    final rows = await executor.query(
      AppDatabase.cashLotConsumptionsTable,
      where: 'lot_id = ? AND is_reversed = 0',
      whereArgs: [lotId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLotConsumption.fromMap).toList();
  }

  /// Returns the **active** (not reversed) source consumptions recorded for the
  /// exchange [exchangeId] (the `exchange_out` draws against source lots).
  ///
  /// Pass [txn] to read inside an outer transaction.
  Future<List<CashLotConsumption>> getActiveConsumptionsByExchangeId(
    String exchangeId, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    final rows = await executor.query(
      AppDatabase.cashLotConsumptionsTable,
      where: 'exchange_id = ? AND is_reversed = 0',
      whereArgs: [exchangeId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLotConsumption.fromMap).toList();
  }

  /// Hard-deletes all consumption rows for [expenseId].
  ///
  /// Call this inside a transaction **before** deleting the expense row so the
  /// FK `ON DELETE SET NULL` trigger never fires and the
  /// `CHECK (expense_id IS NOT NULL)` constraint is not violated.
  Future<void> deleteConsumptionsByExpenseId(
    String expenseId, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    await executor.delete(
      AppDatabase.cashLotConsumptionsTable,
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<void> markConsumptionsReversedForExpense(
    DatabaseExecutor txn,
    String expenseId,
  ) async {
    final now = DateTime.now().toUtc();
    await txn.update(
      AppDatabase.cashLotConsumptionsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
      },
      where: 'expense_id = ? AND is_reversed = 0',
      whereArgs: [expenseId],
    );
  }

  Future<void> markConsumptionsReversedForExchange(
    DatabaseExecutor txn,
    String exchangeId,
  ) async {
    final now = DateTime.now().toUtc();
    await txn.update(
      AppDatabase.cashLotConsumptionsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
      },
      where: 'exchange_id = ? AND is_reversed = 0',
      whereArgs: [exchangeId],
    );
  }
}
