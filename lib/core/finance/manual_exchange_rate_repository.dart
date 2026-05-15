import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import 'manual_exchange_rate.dart';

class ManualExchangeRateRepository {
  const ManualExchangeRateRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> saveRate(ManualExchangeRate rate) async {
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.manualExchangeRatesTable,
      rate.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<ManualExchangeRate?> getLatestRate({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final db = await _appDatabase.database;
    final normalizedTripId = tripId?.trim();
    final normalizedFrom = fromCurrency.trim().toUpperCase();
    final normalizedTo = toCurrency.trim().toUpperCase();

    if (normalizedTripId != null && normalizedTripId.isNotEmpty) {
      final tripRows = await db.query(
        AppDatabase.manualExchangeRatesTable,
        where: 'trip_id = ? AND from_currency = ? AND to_currency = ?',
        whereArgs: [normalizedTripId, normalizedFrom, normalizedTo],
        orderBy: 'created_at DESC',
        limit: 1,
      );

      if (tripRows.isNotEmpty) {
        return ManualExchangeRate.fromMap(tripRows.first);
      }
    }

    final rows = await db.query(
      AppDatabase.manualExchangeRatesTable,
      where: 'trip_id IS NULL AND from_currency = ? AND to_currency = ?',
      whereArgs: [normalizedFrom, normalizedTo],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ManualExchangeRate.fromMap(rows.first);
  }

  Future<List<ManualExchangeRate>> listLatestTripRates(String tripId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      'SELECT m.* '
      'FROM ${AppDatabase.manualExchangeRatesTable} m '
      'INNER JOIN ('
      '  SELECT from_currency, to_currency, MAX(created_at) AS latest_created_at '
      '  FROM ${AppDatabase.manualExchangeRatesTable} '
      '  WHERE trip_id = ? '
      '  GROUP BY from_currency, to_currency'
      ') latest '
      'ON m.from_currency = latest.from_currency '
      'AND m.to_currency = latest.to_currency '
      'AND m.created_at = latest.latest_created_at '
      'WHERE m.trip_id = ? '
      'ORDER BY m.created_at DESC',
      [tripId, tripId],
    );

    return rows.map(ManualExchangeRate.fromMap).toList(growable: false);
  }
}
