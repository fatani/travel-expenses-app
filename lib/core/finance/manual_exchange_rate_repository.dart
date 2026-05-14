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
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.manualExchangeRatesTable,
      where: 'from_currency = ? AND to_currency = ?',
      whereArgs: [
        fromCurrency.trim().toUpperCase(),
        toCurrency.trim().toUpperCase(),
      ],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ManualExchangeRate.fromMap(rows.first);
  }
}
