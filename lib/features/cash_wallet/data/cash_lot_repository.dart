import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/cash_lot.dart';

class CashLotRepository {
  CashLotRepository(this._appDatabase, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<CashLot> insertCashLot(CashLot lot) async {
    final entity = lot.id.isEmpty ? lot.copyWith(id: _uuid.v4()) : lot;
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.cashLotsTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity;
  }

  Future<CashLot?> getCashLotById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CashLot.fromMap(rows.first);
  }

  /// Returns open (not reversed, not fully consumed) lots for the given trip
  /// and currency, ordered oldest-first (FIFO consumption order).
  Future<List<CashLot>> getOpenLotsForCurrency(
    String tripId,
    String currencyCode,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotsTable,
      where:
          'trip_id = ? AND currency_code = ? AND is_reversed = 0 AND is_fully_consumed = 0',
      whereArgs: [tripId, currencyCode.trim().toUpperCase()],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLot.fromMap).toList();
  }

  Future<void> updateLotRemainingAmount(
    String id,
    double newRemainingAmount, {
    DatabaseExecutor? txn,
  }) async {
    final executor = txn ?? await _appDatabase.database;
    await executor.update(
      AppDatabase.cashLotsTable,
      {
        'remaining_amount': newRemainingAmount,
        if (newRemainingAmount <= 0) 'is_fully_consumed': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markLotReversed(String id, {DatabaseExecutor? txn}) async {
    final executor = txn ?? await _appDatabase.database;
    final now = DateTime.now().toUtc();
    await executor.update(
      AppDatabase.cashLotsTable,
      {
        'is_reversed': 1,
        'reversed_at': now.toIso8601String(),
        'is_fully_consumed': 1,
        'remaining_amount': 0.0,
      },
      where: 'id = ? AND is_reversed = 0',
      whereArgs: [id],
    );
  }

  Future<List<CashLot>> getLotsBySourceRef(
    String sourceRefType,
    String sourceRefId,
  ) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashLotsTable,
      where: 'source_ref_type = ? AND source_ref_id = ?',
      whereArgs: [sourceRefType, sourceRefId],
      orderBy: 'created_at ASC',
    );
    return rows.map(CashLot.fromMap).toList();
  }
}
