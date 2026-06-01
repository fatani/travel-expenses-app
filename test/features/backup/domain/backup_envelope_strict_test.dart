import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';

void main() {
  Map<String, dynamic> baseJson() {
    return {
      'manifest': BackupManifest(
        backupFormatVersion: BackupConstants.currentBackupFormatVersion,
        schemaVersion: AppDatabase.databaseVersion,
        appVersion: '1.0.0',
        buildNumber: '1',
        exportedAt: DateTime.utc(2026, 6, 1),
        sourceApp: BackupConstants.sourceApp,
        tripCount: 0,
        expenseCount: 0,
        cashTransactionCount: 0,
        cardCount: 0,
        manualExchangeRateCount: 0,
      ).toJson(),
      BackupEnvelope.userFinancialProfileKey: <Map<String, dynamic>>[],
      BackupEnvelope.settingsKey: <Map<String, dynamic>>[],
      BackupEnvelope.cardsKey: <Map<String, dynamic>>[],
      BackupEnvelope.tripsKey: <Map<String, dynamic>>[],
      BackupEnvelope.manualExchangeRatesKey: <Map<String, dynamic>>[],
      BackupEnvelope.expensesKey: <Map<String, dynamic>>[],
      BackupEnvelope.cashTransactionsKey: <Map<String, dynamic>>[],
    };
  }

  test('fromJsonStrict accepts complete document', () {
    final envelope = BackupEnvelope.fromJsonStrict(baseJson());
    expect(envelope.trips, isEmpty);
  });

  test('fromJson lenient treats missing arrays as empty', () {
    final json = baseJson()
      ..remove(BackupEnvelope.tripsKey)
      ..remove(BackupEnvelope.expensesKey);

    final lenient = BackupEnvelope.fromJson(json);
    expect(lenient.trips, isEmpty);
    expect(lenient.expenses, isEmpty);

    expect(
      () => BackupEnvelope.fromJsonStrict(json),
      throwsFormatException,
    );
  });

  test('fromJsonStrict rejects null required arrays', () {
    final json = baseJson()..[BackupEnvelope.cardsKey] = null;

    expect(
      () => BackupEnvelope.fromJsonStrict(json),
      throwsFormatException,
    );
  });

  test('fromJsonStrict rejects wrong types', () {
    final json = baseJson()..[BackupEnvelope.tripsKey] = 'not-a-list';

    expect(
      () => BackupEnvelope.fromJsonStrict(json),
      throwsFormatException,
    );
  });

  test('fromJsonStrict rejects null row elements', () {
    final json = baseJson()
      ..[BackupEnvelope.expensesKey] = <dynamic>[null];

    expect(
      () => BackupEnvelope.fromJsonStrict(json),
      throwsFormatException,
    );
  });
}
