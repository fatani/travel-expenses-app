import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/backup/data/backup_export_service.dart';
import 'package:travel_expenses/features/backup/data/backup_file_writer.dart';
import 'package:travel_expenses/features/backup/data/backup_restore_service.dart';
import 'package:travel_expenses/features/backup/data/backup_restore_verifier.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_restore_failure.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
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
  late BackupRestoreService restoreService;
  late TripRepository tripRepository;
  late ExpenseRefundRepository refundRepository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('refund_backup_test_');
    appDatabase = createIsolatedAppDatabase(prefix: 'refund_backup');
    final collector = BackupDataCollector(appDatabase);
    exportService = BackupExportService(
      collector: collector,
      fileWriter: BackupFileWriter(directoryProvider: () async => tempDir),
    );
    restoreService = BackupRestoreService(appDatabase: appDatabase);
    tripRepository = TripRepository(appDatabase);
    refundRepository = ExpenseRefundRepository(appDatabase);
  });

  tearDown(() async {
    BackupRestoreVerifier.testHook = null;
    await appDatabase.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Trip> seedTrip(String suffix) => tripRepository.createTrip(
        Trip.create(
          id: 'trip-$suffix',
          name: 'Trip $suffix',
          destination: 'Tokyo',
          baseCurrency: 'JPY',
          destinationCurrency: 'JPY',
          homeCurrencySnapshot: 'SAR',
        ),
      );

  Future<int> refundCount({bool includeReversed = true}) async {
    final db = await appDatabase.database;
    final where = includeReversed ? null : 'is_reversed = 0';
    final rows = await db.query(AppDatabase.expenseRefundsTable, where: where);
    return rows.length;
  }

  // ---------------------------------------------------------------------------
  // Backup includes expense_refunds
  // ---------------------------------------------------------------------------

  test('backup envelope includes expense_refunds key', () async {
    final trip = await seedTrip('bk1');
    await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 100.0,
      currencyCode: 'JPY',
    );

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );
    final json = jsonDecode(await File(result.filePath).readAsString()) as Map<String, dynamic>;

    expect(json.containsKey(BackupEnvelope.expenseRefundsKey), isTrue);
    final refunds = json[BackupEnvelope.expenseRefundsKey] as List;
    expect(refunds.length, 1);
  });

  test('manifest refund_count matches actual refund rows', () async {
    final trip = await seedTrip('bk2');
    await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 50.0,
      currencyCode: 'JPY',
    );
    await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 75.0,
      currencyCode: 'JPY',
    );

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );
    final json = jsonDecode(await File(result.filePath).readAsString()) as Map<String, dynamic>;
    final manifest = json['manifest'] as Map<String, dynamic>;

    expect(manifest['refund_count'], 2);
  });

  // ---------------------------------------------------------------------------
  // Old backup without expense_refunds restores successfully
  // ---------------------------------------------------------------------------

  test('old backup without expense_refunds key restores with empty refund list', () async {
    await seedTrip('bk3');

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );
    final file = File(result.filePath);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    // Simulate old backup: remove expense_refunds and reset refund_count.
    json.remove(BackupEnvelope.expenseRefundsKey);
    (json['manifest'] as Map<String, dynamic>).remove('refund_count');
    await file.writeAsString(jsonEncode(json));

    // Wipe DB and restore from old-style backup.
    final db = await appDatabase.database;
    await db.delete(AppDatabase.tripCashBalancesTable);
    await db.delete(AppDatabase.expenseRefundsTable);
    await db.delete(AppDatabase.cashTransactionsTable);
    await db.delete(AppDatabase.expensesTable);
    await db.delete(AppDatabase.tripsTable);

    final contents = await file.readAsString();
    final preview = restoreService.loadPreview(
      fileName: result.filePath,
      contents: contents,
    );
    await restoreService.restore(preview.envelope);

    expect(await refundCount(), 0);
    final tripRows = await db.query(AppDatabase.tripsTable);
    expect(tripRows.length, 1);
  });

  // ---------------------------------------------------------------------------
  // Restore round-trip preserves active and reversed refunds
  // ---------------------------------------------------------------------------

  test('restore round-trip preserves active and reversed refunds', () async {
    final trip = await seedTrip('bk4');

    await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 200.0,
      currencyCode: 'JPY',
    );
    final reversedRefund = await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 50.0,
      currencyCode: 'JPY',
    );
    await refundRepository.reverseCardRefund(reversedRefund);

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );

    final db = await appDatabase.database;
    await db.delete(AppDatabase.tripCashBalancesTable);
    await db.delete(AppDatabase.expenseRefundsTable);
    await db.delete(AppDatabase.cashTransactionsTable);
    await db.delete(AppDatabase.expensesTable);
    await db.delete(AppDatabase.tripsTable);

    final contents = await File(result.filePath).readAsString();
    final preview = restoreService.loadPreview(
      fileName: result.filePath,
      contents: contents,
    );
    await restoreService.restore(preview.envelope);

    expect(await refundCount(includeReversed: true), 2);
    expect(await refundCount(includeReversed: false), 1);
  });

  // ---------------------------------------------------------------------------
  // Validator rejects invalid destination
  // ---------------------------------------------------------------------------

  test('validator rejects unknown refund destination', () async {
    final trip = await seedTrip('bk5');

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );
    final file = File(result.filePath);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    // Inject a refund row with invalid destination.
    final refundRows = (json[BackupEnvelope.expenseRefundsKey] as List?) ?? [];
    refundRows.add({
      'id': 'bad-refund-1',
      'trip_id': trip.id,
      'expense_id': null,
      'amount': 10.0,
      'currency_code': 'JPY',
      'home_amount': null,
      'home_currency': null,
      'destination': 'wallet',
      'note': null,
      'is_reversed': 0,
      'reversed_at': null,
      'created_at': '2026-06-09T10:00:00.000Z',
    });
    json[BackupEnvelope.expenseRefundsKey] = refundRows;
    (json['manifest'] as Map<String, dynamic>)['refund_count'] = 1;
    await file.writeAsString(jsonEncode(json));

    final contents = await file.readAsString();
    expect(
      () => restoreService.loadPreview(
        fileName: result.filePath,
        contents: contents,
      ),
      throwsA(isA<BackupRestoreException>()),
    );
  });

  // ---------------------------------------------------------------------------
  // Validator rejects invalid is_reversed value
  // ---------------------------------------------------------------------------

  test('validator rejects is_reversed value other than 0 or 1', () async {
    final trip = await seedTrip('bk6');

    final result = await exportService.export(
      exportedAt: DateTime.utc(2026, 6, 9),
    );
    final file = File(result.filePath);
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final refundRows = (json[BackupEnvelope.expenseRefundsKey] as List?) ?? [];
    refundRows.add({
      'id': 'bad-reversed-1',
      'trip_id': trip.id,
      'expense_id': null,
      'amount': 10.0,
      'currency_code': 'JPY',
      'home_amount': null,
      'home_currency': null,
      'destination': 'card',
      'note': null,
      'is_reversed': 2,
      'reversed_at': null,
      'created_at': '2026-06-09T10:00:00.000Z',
    });
    json[BackupEnvelope.expenseRefundsKey] = refundRows;
    (json['manifest'] as Map<String, dynamic>)['refund_count'] = 1;
    await file.writeAsString(jsonEncode(json));

    final contents = await file.readAsString();
    expect(
      () => restoreService.loadPreview(
        fileName: result.filePath,
        contents: contents,
      ),
      throwsA(isA<BackupRestoreException>()),
    );
  });
}
