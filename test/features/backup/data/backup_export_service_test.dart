import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/features/backup/data/backup_collected_data.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/data/backup_export_service.dart';
import 'package:travel_expenses/features/backup/data/backup_file_writer.dart';
import 'package:travel_expenses/features/backup/data/backup_manifest_builder.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late AppDatabase appDatabase;
  late BackupExportService exportService;
  late BackupDataCollector collector;
  late BackupManifestBuilder manifestBuilder;

  final exportedAt = DateTime.utc(2026, 6, 1, 14, 30, 45);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_export_test_');
    appDatabase = createIsolatedAppDatabase(prefix: 'backup_export');
    collector = BackupDataCollector(appDatabase);
    manifestBuilder = const BackupManifestBuilder();
    exportService = BackupExportService(
      collector: collector,
      fileWriter: BackupFileWriter(
        directoryProvider: () async => tempDir,
      ),
    );
  });

  tearDown(() async {
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<BackupEnvelope> exportEnvelope() async {
    final result = await exportService.export(exportedAt: exportedAt);
    final raw = await File(result.filePath).readAsString();
    return BackupEnvelope.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }

  test('manifest counts match collected data', () async {
    final data = await collector.collect();
    final manifest = manifestBuilder.build(data, exportedAt: exportedAt);

    expect(manifest.tripCount, data.trips.length);
    expect(manifest.expenseCount, data.expenses.length);
    expect(manifest.cashTransactionCount, data.cashTransactions.length);
    expect(manifest.cardCount, data.cards.length);
    expect(manifest.manualExchangeRateCount, data.manualExchangeRates.length);
  });

  test('backup JSON is valid and round-trips', () async {
    final envelope = await exportEnvelope();

    expect(envelope.manifest.backupFormatVersion, BackupConstants.currentBackupFormatVersion);
    expect(envelope.manifest.schemaVersion, AppDatabase.databaseVersion);
    expect(envelope.manifest.sourceApp, BackupConstants.sourceApp);
    expect(envelope.manifest.exportedAt, exportedAt);
  });

  test('backup file name uses .clbackup extension and timestamp pattern', () async {
    final result = await exportService.export(exportedAt: exportedAt);

    expect(result.fileName, 'calmledger-backup-2026-06-01-143045.clbackup');
    expect(result.fileName.endsWith(BackupConstants.fileExtension), isTrue);
    expect(File(result.filePath).existsSync(), isTrue);
  });

  test('export works with empty database', () async {
    final envelope = await exportEnvelope();

    expect(envelope.trips, isEmpty);
    expect(envelope.expenses, isEmpty);
    expect(envelope.cashTransactions, isEmpty);
    expect(envelope.cards, isEmpty);
    expect(envelope.manualExchangeRates, isEmpty);
    expect(envelope.manifest.tripCount, 0);
    expect(envelope.manifest.expenseCount, 0);
  });

  test('export includes trips, expenses, cards, cash transactions, manual rates', () async {
    final tripRepository = TripRepository(appDatabase);
    final expenseRepository = ExpenseRepository(appDatabase);
    final cashWalletRepository = CashWalletRepository(appDatabase);
    final cardRepository = CardRepository(appDatabase);
    final exchangeRateRepository = ManualExchangeRateRepository(appDatabase);

    final trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-backup-1',
        name: 'Osaka',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );

    await cardRepository.addCard(name: 'Travel Visa');

    await expenseRepository.createExpense(
      Expense.create(
        id: 'exp-backup-1',
        tripId: trip.id,
        title: 'Ramen',
        amount: 1200,
        currencyCode: 'JPY',
        transactionAmount: 1200,
        transactionCurrency: 'JPY',
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
      ),
    );

    await cashWalletRepository.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: 5000,
      currencyCode: 'JPY',
    );

    await exchangeRateRepository.saveRate(
      ManualExchangeRate.create(
        tripId: trip.id,
        fromCurrency: 'JPY',
        toCurrency: 'SAR',
        rate: 0.025,
        createdAt: exportedAt,
      ),
    );

    final envelope = await exportEnvelope();

    expect(envelope.trips, hasLength(1));
    expect(envelope.expenses, hasLength(1));
    expect(envelope.cashTransactions, hasLength(1));
    expect(envelope.cards, hasLength(1));
    expect(envelope.manualExchangeRates, hasLength(1));
    expect(envelope.manifest.tripCount, 1);
    expect(envelope.manifest.expenseCount, 1);
    expect(envelope.manifest.cashTransactionCount, 1);
    expect(envelope.manifest.cardCount, 1);
    expect(envelope.manifest.manualExchangeRateCount, 1);
    expect(envelope.trips.first['id'], trip.id);
    expect(envelope.expenses.first['title'], 'Ramen');
  });

  test('serialized document excludes trip_cash_balances key', () async {
    final envelope = await exportEnvelope();
    final json = envelope.toJson();

    expect(json.containsKey(BackupEnvelope.excludedTripCashBalancesKey), isFalse);
  });

  test('manifest builder sets format metadata', () {
    final manifest = manifestBuilder.build(
      const BackupCollectedData(),
      exportedAt: exportedAt,
    );

    expect(manifest.backupFormatVersion, 1);
    expect(manifest.schemaVersion, 17);
    expect(manifest.sourceApp, BackupConstants.sourceApp);
  });
}
