import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/data/backup_export_service.dart';
import 'package:travel_expenses/features/backup/data/backup_file_reader.dart';
import 'package:travel_expenses/features/backup/data/backup_file_writer.dart';
import 'package:travel_expenses/features/backup/data/backup_restore_service.dart';
import 'package:travel_expenses/features/backup/data/backup_restore_verifier.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_restore_failure.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_balance_recompute.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_calculator.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
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
  late BackupDataCollector collector;
  late BackupExportService exportService;
  late BackupRestoreService restoreService;

  final exportedAt = DateTime.utc(2026, 6, 1, 14, 30, 45);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_restore_test_');
    appDatabase = createIsolatedAppDatabase(prefix: 'backup_restore');
    collector = BackupDataCollector(appDatabase);
    exportService = BackupExportService(
      collector: collector,
      fileWriter: BackupFileWriter(
        directoryProvider: () async => tempDir,
      ),
    );
    restoreService = BackupRestoreService(appDatabase: appDatabase);
  });

  tearDown(() async {
    BackupRestoreVerifier.testHook = null;
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedSampleData() async {
    final tripRepository = TripRepository(appDatabase);
    final expenseRepository = ExpenseRepository(appDatabase);
    final cashWalletRepository = CashWalletRepository(appDatabase);
    final cardRepository = CardRepository(appDatabase);
    final exchangeRateRepository = ManualExchangeRateRepository(appDatabase);

    final trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-restore-1',
        name: 'Osaka',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
        startDate: DateTime(2026, 6, 1),
        endDate: DateTime(2026, 6, 5),
      ),
    );

    final card = await cardRepository.addCard(name: 'Travel Visa');

    await expenseRepository.createExpense(
      Expense.create(
        id: 'exp-restore-1',
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

    await expenseRepository.createExpense(
      Expense.create(
        id: 'exp-restore-2',
        tripId: trip.id,
        title: 'Hotel',
        amount: 24000,
        currencyCode: 'JPY',
        transactionAmount: 24000,
        transactionCurrency: 'JPY',
        paymentMethod: 'Credit Card',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
        category: 'Accommodation',
        cardProfileId: card.id,
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
  }

  Future<String> exportBackupContents() async {
    final result = await exportService.export(exportedAt: exportedAt);
    return File(result.filePath).readAsStringSync();
  }

  Future<BackupEnvelope> exportEnvelope() async {
    final raw = jsonDecode(await exportBackupContents()) as Map<String, dynamic>;
    return BackupEnvelope.fromJson(raw);
  }

  Map<String, dynamic> collectedDataToComparableMap(
    List<Map<String, dynamic>> rows,
  ) {
    // Backup format v1 does not round-trip the FIFO lot ledger; restore
    // intentionally strips lot/exchange references. Exclude them from
    // row equality.
    const strippedOnRestore = {'lot_id', 'exchange_id', 'returned_lot_id'};
    return {
      for (final row in rows)
        restoreTestRowKey(row): Map<String, dynamic>.from(row)
          ..removeWhere((key, _) => strippedOnRestore.contains(key)),
    };
  }

  test('export → restore → equality', () async {
    await seedSampleData();
    final before = await collector.collect();
    final envelope = await exportEnvelope();

    await TripRepository(appDatabase).createTrip(
      Trip.create(
        id: 'trip-should-vanish',
        name: 'Noise',
        destination: 'Nowhere',
        baseCurrency: 'USD',
        destinationCurrency: 'USD',
        homeCurrencySnapshot: 'USD',
      ),
    );

    await restoreService.restore(envelope);
    final after = await collector.collect();

    expect(
      collectedDataToComparableMap(after.trips),
      collectedDataToComparableMap(before.trips),
    );
    expect(
      collectedDataToComparableMap(after.expenses),
      collectedDataToComparableMap(before.expenses),
    );
    expect(
      collectedDataToComparableMap(after.cashTransactions),
      collectedDataToComparableMap(before.cashTransactions),
    );
    expect(
      collectedDataToComparableMap(after.cards),
      collectedDataToComparableMap(before.cards),
    );
    expect(
      collectedDataToComparableMap(after.manualExchangeRates),
      collectedDataToComparableMap(before.manualExchangeRates),
    );
  });

  test('backup file restores onto a fresh database with reports intact', () async {
    await seedSampleData();
    final backupContents = await exportBackupContents();
    final preview = restoreService.loadPreview(
      fileName: 'calmledger-backup-2026-06-01-143045.clbackup',
      contents: backupContents,
    );

    final freshDatabase = createIsolatedAppDatabase(
      prefix: 'backup_restore_transfer_target',
    );
    try {
      await BackupRestoreService(appDatabase: freshDatabase)
          .restore(preview.envelope);

      final tripRepository = TripRepository(freshDatabase);
      final expenseRepository = ExpenseRepository(freshDatabase);
      final cashWalletRepository = CashWalletRepository(freshDatabase);
      final cardRepository = CardRepository(freshDatabase);
      final restoredTrips = await tripRepository.getTrips();
      final restoredCards = await cardRepository.getAllCards();

      expect(restoredTrips, hasLength(1));
      expect(restoredTrips.single.id, 'trip-restore-1');
      expect(restoredTrips.single.name, 'Osaka');
      expect(restoredCards, hasLength(1));
      expect(restoredCards.single.name, 'Travel Visa');

      final restoredExpenses =
          await expenseRepository.getExpensesByTrip(restoredTrips.single.id);
      final restoredCashTransactions = await cashWalletRepository
          .getRecentTransactionsByTrip(restoredTrips.single.id);
      final restoredCashBalances =
          await cashWalletRepository.getBalancesByTrip(restoredTrips.single.id);

      expect(restoredExpenses, hasLength(2));
      expect(
        restoredExpenses.map((expense) => expense.title),
        containsAll(['Ramen', 'Hotel']),
      );
      expect(
        restoredExpenses.singleWhere((expense) => expense.title == 'Hotel')
            .cardProfileId,
        restoredCards.single.id,
      );
      expect(restoredCashTransactions, hasLength(1));
      expect(restoredCashTransactions.single.amount, 5000);
      expect(restoredCashBalances, hasLength(1));
      expect(restoredCashBalances.single.balanceAmount, 5000);

      final tripReport = const TripReportCalculator().calculate(
        tripId: restoredTrips.single.id,
        tripName: restoredTrips.single.name,
        expenses: restoredExpenses,
      );
      expect(tripReport.totalExpenseCount, 2);
      expect(tripReport.totalBilledByCurrency.single.currency, 'JPY');
      expect(tripReport.totalBilledByCurrency.single.totalAmount, 25200);
      expect(
        tripReport.byPaymentChannel.map((bucket) => bucket.key),
        containsAll(['Cash', 'POS Purchase']),
      );

      final globalReport = const GlobalReportCalculator().calculate(
        trips: restoredTrips,
        expenses: restoredExpenses,
      );
      expect(globalReport.totalTrips, 1);
      expect(globalReport.activeTrips, 1);
      expect(globalReport.totalExpenseCount, 2);
      expect(globalReport.totalBilledByCurrency.single.currency, 'JPY');
      expect(globalReport.totalBilledByCurrency.single.totalAmount, 25200);
      expect(globalReport.trackedTripDays, 5);
    } finally {
      await freshDatabase.close();
    }
  });

  test('empty backup restore', () async {
    final envelope = await exportEnvelope();
    expect(envelope.trips, isEmpty);

    await restoreService.restore(envelope);
    final after = await collector.collect();

    expect(after.trips, isEmpty);
    expect(after.expenses, isEmpty);
    expect(after.cashTransactions, isEmpty);
  });

  test('corrupt file restore', () {
    expect(
      () => restoreService.loadPreview(
        fileName: 'bad.clbackup',
        contents: '{not json',
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (e) => e.kind,
          'kind',
          BackupRestoreFailureKind.corruptBackup,
        ),
      ),
    );
  });

  test('invalid file extension is rejected', () {
    expect(
      () => const BackupFileReader().readJson(
        fileName: 'backup.json',
        contents: '{}',
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (e) => e.kind,
          'kind',
          BackupRestoreFailureKind.invalidBackupFile,
        ),
      ),
    );
  });

  test('missing array restore', () async {
    final raw =
        jsonDecode(await exportBackupContents()) as Map<String, dynamic>;
    raw.remove(BackupEnvelope.tripsKey);

    expect(
      () => restoreService.previewFromJson(raw),
      throwsA(isA<BackupRestoreException>()),
    );
  });

  test('duplicate ID restore is rejected before DB write', () async {
    final envelope = await exportEnvelope();
    final json = envelope.toJson();
    final trips = List<Map<String, dynamic>>.from(
      json[BackupEnvelope.tripsKey] as List,
    );
    if (trips.isEmpty) {
      trips.add({
        'id': 'dup-trip',
        'name': 'A',
        'destination': 'B',
        'base_currency': 'USD',
        'created_at': exportedAt.toIso8601String(),
        'updated_at': exportedAt.toIso8601String(),
        'is_custom_title': 0,
      });
    }
    trips.add(Map<String, dynamic>.from(trips.first));

    json[BackupEnvelope.tripsKey] = trips;
    (json['manifest'] as Map<String, dynamic>)['trip_count'] = trips.length;

    expect(
      () => restoreService.previewFromJson(json),
      throwsA(isA<BackupRestoreException>()),
    );
  });

  test('FK violation restore is rejected before DB write', () async {
    final envelope = await exportEnvelope();
    final json = envelope.toJson();
    json[BackupEnvelope.expensesKey] = [
      {
        'id': 'orphan-exp',
        'trip_id': 'missing-trip',
        'title': 'Ghost',
        'amount': 1.0,
        'currency_code': 'USD',
        'spent_at': exportedAt.toIso8601String(),
        'payment_method': 'Cash',
        'source': 'manual',
        'created_at': exportedAt.toIso8601String(),
        'updated_at': exportedAt.toIso8601String(),
        'is_international': 0,
      },
    ];
    (json['manifest'] as Map<String, dynamic>)['expense_count'] = 1;

    expect(
      () => restoreService.previewFromJson(json),
      throwsA(isA<BackupRestoreException>()),
    );
  });

  test('future schema restore rejection', () {
    final json = _minimalValidJson();
    (json['manifest'] as Map<String, dynamic>)['schema_version'] = 99;

    expect(
      () => restoreService.previewFromJson(json),
      throwsA(
        isA<BackupRestoreException>().having(
          (e) => e.kind,
          'kind',
          BackupRestoreFailureKind.unsupportedSchemaVersion,
        ),
      ),
    );
  });

  test('future format restore rejection', () {
    final json = _minimalValidJson();
    (json['manifest'] as Map<String, dynamic>)['backup_format_version'] = 99;

    expect(
      () => restoreService.previewFromJson(json),
      throwsA(
        isA<BackupRestoreException>().having(
          (e) => e.kind,
          'kind',
          BackupRestoreFailureKind.unsupportedBackupVersion,
        ),
      ),
    );
  });

  test('rollback test leaves original data intact', () async {
    await seedSampleData();
    final before = await collector.collect();
    final envelope = await exportEnvelope();

    BackupRestoreVerifier.testHook = (txn, _) async {
      throw StateError('forced verification failure');
    };

    expect(
      () => restoreService.restore(envelope),
      throwsA(
        isA<BackupRestoreException>().having(
          (e) => e.kind,
          'kind',
          BackupRestoreFailureKind.restoreFailed,
        ),
      ),
    );

    final afterFailed = await collector.collect();
    expect(
      collectedDataToComparableMap(afterFailed.trips),
      collectedDataToComparableMap(before.trips),
    );
    expect(
      collectedDataToComparableMap(afterFailed.expenses),
      collectedDataToComparableMap(before.expenses),
    );
  });

  test('balance recomputation test', () async {
    await seedSampleData();
    final envelope = await exportEnvelope();

    await restoreService.restore(envelope);

    final db = await appDatabase.database;
    final balanceRows = await db.query(AppDatabase.tripCashBalancesTable);
    final expected = CashBalanceRecompute.recomputeTripCashBalances(
      envelope.cashTransactions,
    );

    expect(balanceRows.length, expected.length);
    for (final expectedBalance in expected) {
      final match = balanceRows.where(
        (row) =>
            row['trip_id'] == expectedBalance.tripId &&
            row['currency_code'] == expectedBalance.currencyCode,
      );
      expect(match, hasLength(1));
      expect(
        (match.first['balance_amount'] as num).toDouble(),
        closeTo(expectedBalance.balanceAmount, 0.000001),
      );
    }
  });
}

String restoreTestRowKey(Map<String, dynamic> row) {
  if (row.containsKey('id')) {
    final id = row['id'];
    if (id is String) {
      return 'id:$id';
    }
    if (id is int) {
      return 'id:$id';
    }
  }
  if (row.containsKey('trip_id') && row.containsKey('currency_code')) {
    return 'balance:${row['trip_id']}|${row['currency_code']}';
  }
  return row.entries.map((e) => '${e.key}=${e.value}').join('|');
}

Map<String, dynamic> _minimalValidJson() {
  final exportedAt = DateTime.utc(2026, 6, 1);
  return {
    'manifest': {
      'backup_format_version': BackupConstants.currentBackupFormatVersion,
      'schema_version': BackupConstants.currentSchemaVersion,
      'app_version': '1.0.0',
      'build_number': '1',
      'exported_at': exportedAt.toIso8601String(),
      'source_app': BackupConstants.sourceApp,
      'trip_count': 0,
      'expense_count': 0,
      'cash_transaction_count': 0,
      'card_count': 0,
      'manual_exchange_rate_count': 0,
    },
    BackupEnvelope.userFinancialProfileKey: <Map<String, dynamic>>[],
    BackupEnvelope.settingsKey: <Map<String, dynamic>>[],
    BackupEnvelope.cardsKey: <Map<String, dynamic>>[],
    BackupEnvelope.tripsKey: <Map<String, dynamic>>[],
    BackupEnvelope.manualExchangeRatesKey: <Map<String, dynamic>>[],
    BackupEnvelope.expensesKey: <Map<String, dynamic>>[],
    BackupEnvelope.cashTransactionsKey: <Map<String, dynamic>>[],
  };
}
