import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import 'backup_collected_data.dart';

/// Reads source-of-truth SQLite tables for backup export.
class BackupDataCollector {
  const BackupDataCollector(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<BackupCollectedData> collect() async {
    final db = await _appDatabase.database;

    return BackupCollectedData(
      userFinancialProfile: await _queryTable(
        db,
        AppDatabase.userFinancialProfileTable,
      ),
      settings: await _queryTable(db, AppDatabase.settingsTable),
      cards: await _queryTable(db, AppDatabase.cardsTable),
      trips: await _queryTable(db, AppDatabase.tripsTable),
      manualExchangeRates: await _queryTable(
        db,
        AppDatabase.manualExchangeRatesTable,
      ),
      expenses: await _queryTable(db, AppDatabase.expensesTable),
      cashTransactions: await _queryTable(
        db,
        AppDatabase.cashTransactionsTable,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _queryTable(
    Database db,
    String table,
  ) async {
    final rows = await db.query(table);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  }
}
