import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/data/backup_collected_data.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late BackupDataCollector collector;

  setUp(() {
    appDatabase = createIsolatedAppDatabase(prefix: 'backup_collector');
    collector = BackupDataCollector(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('includes all required source-of-truth tables', () async {
    final data = await collector.collect();

    expect(BackupCollectedData.exportedTableNames, hasLength(7));
    expect(BackupCollectedData.exportedTableNames, containsAll([
      AppDatabase.userFinancialProfileTable,
      AppDatabase.settingsTable,
      AppDatabase.cardsTable,
      AppDatabase.tripsTable,
      AppDatabase.manualExchangeRatesTable,
      AppDatabase.expensesTable,
      AppDatabase.cashTransactionsTable,
    ]));

    expect(data.userFinancialProfile, isA<List<Map<String, dynamic>>>());
    expect(data.settings, isA<List<Map<String, dynamic>>>());
    expect(data.cards, isA<List<Map<String, dynamic>>>());
    expect(data.trips, isA<List<Map<String, dynamic>>>());
    expect(data.manualExchangeRates, isA<List<Map<String, dynamic>>>());
    expect(data.expenses, isA<List<Map<String, dynamic>>>());
    expect(data.cashTransactions, isA<List<Map<String, dynamic>>>());
  });

  test('excludes trip_cash_balances from exported table list', () {
    expect(
      BackupCollectedData.excludedTableName,
      AppDatabase.tripCashBalancesTable,
    );
    expect(
      BackupCollectedData.exportedTableNames,
      isNot(contains(AppDatabase.tripCashBalancesTable)),
    );
    expect(BackupEnvelope.excludedTripCashBalancesKey, 'trip_cash_balances');
  });
}
