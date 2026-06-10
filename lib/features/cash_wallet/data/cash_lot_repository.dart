import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/cash_lot.dart';
import '../domain/cash_lot_currency_summary.dart';

class CashLotRepository {
  CashLotRepository(this._appDatabase, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<CashLot> insertCashLot(CashLot lot, {DatabaseExecutor? txn}) async {
    final entity = lot.id.isEmpty ? lot.copyWith(id: _uuid.v4()) : lot;
    final executor = txn ?? await _appDatabase.database;
    await executor.insert(
      AppDatabase.cashLotsTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return entity;
  }

  /// Patches [source_ref_id] for a lot whose ref was not yet known at insert
  /// time (e.g. the cash_transaction ID is generated inside the same txn).
  Future<void> updateLotSourceRef(
    {required String lotId,
    required String sourceRefId,
    DatabaseExecutor? txn}) async {
    final executor = txn ?? await _appDatabase.database;
    await executor.update(
      AppDatabase.cashLotsTable,
      {'source_ref_id': sourceRefId},
      where: 'id = ?',
      whereArgs: [lotId],
    );
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
      orderBy: 'created_at ASC, id ASC',
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

  /// Aggregates open lots into per-currency summaries for the Remaining Cash
  /// Value report section.
  ///
  /// Only lots that satisfy **all** of the following criteria are included:
  /// * `is_reversed = 0`
  /// * `remaining_amount > 0`
  /// * `effective_rate IS NOT NULL`
  /// * `home_currency_code = [homeCurrencyCode]`
  ///
  /// For each currency the returned summary carries:
  /// * `totalRemainingAmount` = SUM(remaining_amount)
  /// * `totalHomeAmount`      = SUM(remaining_amount × effective_rate)
  ///
  /// The display rate (homeAmount / totalRemainingAmount) is intentionally left
  /// to the caller to compute so the repository remains a thin data layer.
  Future<List<CashLotCurrencySummary>> computeLotCurrencySummaries({
    required String tripId,
    required String homeCurrencyCode,
  }) async {
    final db = await _appDatabase.database;
    final normalizedHome = homeCurrencyCode.trim().toUpperCase();

    final rows = await db.rawQuery(
      '''
      SELECT
        currency_code,
        SUM(remaining_amount)                      AS total_remaining,
        SUM(remaining_amount * effective_rate)     AS total_home
      FROM ${AppDatabase.cashLotsTable}
      WHERE trip_id = ?
        AND is_reversed = 0
        AND remaining_amount > 0
        AND effective_rate IS NOT NULL
        AND home_currency_code = ?
      GROUP BY currency_code
      ''',
      [tripId, normalizedHome],
    );

    return rows.map((row) {
      final totalRemaining = (row['total_remaining'] as num).toDouble();
      final totalHome = (row['total_home'] as num).toDouble();
      return CashLotCurrencySummary(
        currencyCode: (row['currency_code']! as String).trim().toUpperCase(),
        totalRemainingAmount: totalRemaining,
        totalHomeAmount: totalHome,
        homeCurrencyCode: normalizedHome,
      );
    }).toList();
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
