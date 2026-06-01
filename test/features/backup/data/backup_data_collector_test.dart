import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/data/backup_collected_data.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

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

  test('collect returns a fresh snapshot after another connection commits',
      () async {
    final dbPath = (await appDatabase.database).path;
    final before = await collector.collect();
    expect(before.trips, isEmpty);

    final writer = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await writer.insert(AppDatabase.tripsTable, {
      'id': 'committed-trip',
      'name': 'Committed',
      'destination': 'Committed',
      'base_currency': 'USD',
      'destination_currency': 'USD',
      'home_currency_snapshot': 'USD',
      'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'is_custom_title': 0,
    });
    await writer.close();

    final after = await collector.collect();
    expect(
      after.trips.any((row) => row['id'] == 'committed-trip'),
      isTrue,
    );
  });

  test('collect snapshot is referentially consistent for linked rows', () async {
    final tripRepo = TripRepository(appDatabase);
    final trip = await tripRepo.createTrip(
      Trip.create(
        name: 'Paris',
        destination: 'Paris',
        baseCurrency: 'EUR',
        destinationCurrency: 'EUR',
      ),
    );

    final db = await appDatabase.database;
    await db.insert(AppDatabase.expensesTable, {
      'id': 'exp-linked',
      'trip_id': trip.id,
      'title': 'Metro',
      'amount': 5.0,
      'currency_code': 'EUR',
      'transaction_amount': 5.0,
      'transaction_currency': 'EUR',
      'is_international': 0,
      'spent_at': DateTime.utc(2026, 6, 1).toIso8601String(),
      'payment_method': 'Cash',
      'source': 'manual',
      'created_at': DateTime.utc(2026, 6, 1).toIso8601String(),
      'updated_at': DateTime.utc(2026, 6, 1).toIso8601String(),
    });

    final data = await collector.collect();
    final tripIds = data.trips.map((row) => row['id'] as String).toSet();

    for (final expense in data.expenses) {
      expect(tripIds, contains(expense['trip_id']));
    }
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
