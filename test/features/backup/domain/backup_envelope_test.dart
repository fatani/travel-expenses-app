import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';

void main() {
  BackupManifest buildManifest() {
    return BackupManifest(
      backupFormatVersion: BackupConstants.currentBackupFormatVersion,
      schemaVersion: AppDatabase.databaseVersion,
      appVersion: '1.0.0',
      buildNumber: '1',
      exportedAt: DateTime.utc(2026, 6, 1, 12, 0, 0),
      sourceApp: BackupConstants.sourceApp,
      tripCount: 1,
      expenseCount: 2,
      cashTransactionCount: 3,
      cardCount: 4,
      manualExchangeRateCount: 5,
    );
  }

  test('serializes and deserializes correctly', () {
    final envelope = BackupEnvelope(
      manifest: buildManifest(),
      userFinancialProfile: [
        {'id': 1, 'home_currency_code': 'SAR'},
      ],
      settings: [
        {'id': 1, 'currency_code': 'USD', 'locale_code': 'ar'},
      ],
      cards: [
        {'id': 1, 'name': 'Primary'},
      ],
      trips: [
        {'id': 'trip-1', 'name': 'Tokyo'},
      ],
      manualExchangeRates: [
        {
          'trip_id': 'trip-1',
          'from_currency': 'USD',
          'to_currency': 'JPY',
          'rate': 150.0,
        },
      ],
      expenses: [
        {'id': 'exp-1', 'trip_id': 'trip-1', 'title': 'Coffee'},
        {'id': 'exp-2', 'trip_id': 'trip-1', 'title': 'Train'},
      ],
      cashTransactions: [
        {'id': 'cash-1', 'trip_id': 'trip-1', 'amount': 100.0},
      ],
    );

    final roundTrip = BackupEnvelope.fromJson(envelope.toJson());

    expect(roundTrip.manifest.tripCount, 1);
    expect(roundTrip.userFinancialProfile, hasLength(1));
    expect(roundTrip.settings.first['currency_code'], 'USD');
    expect(roundTrip.cards.first['name'], 'Primary');
    expect(roundTrip.trips.first['id'], 'trip-1');
    expect(roundTrip.manualExchangeRates.first['rate'], 150.0);
    expect(roundTrip.expenses, hasLength(2));
    expect(roundTrip.cashTransactions.first['id'], 'cash-1');
  });

  test('json round-trip via encode/decode preserves envelope', () {
    final envelope = BackupEnvelope(
      manifest: buildManifest(),
      trips: [
        {'id': 'trip-1', 'name': 'Paris'},
      ],
    );

    final decoded =
        jsonDecode(jsonEncode(envelope.toJson())) as Map<String, dynamic>;
    final roundTrip = BackupEnvelope.fromJson(decoded);

    expect(roundTrip.trips.single['name'], 'Paris');
    expect(roundTrip.manifest.sourceApp, BackupConstants.sourceApp);
  });

  test('excludes trip_cash_balances from serialized document', () {
    final json = BackupEnvelope(manifest: buildManifest()).toJson();

    expect(json.containsKey(BackupEnvelope.excludedTripCashBalancesKey), isFalse);
    expect(
      json.keys,
      containsAll([
        'manifest',
        BackupEnvelope.userFinancialProfileKey,
        BackupEnvelope.settingsKey,
        BackupEnvelope.cardsKey,
        BackupEnvelope.tripsKey,
        BackupEnvelope.manualExchangeRatesKey,
        BackupEnvelope.expensesKey,
        BackupEnvelope.cashTransactionsKey,
      ]),
    );
  });

  test('manifest metadata counts are preserved through envelope', () {
    final manifest = BackupManifest(
      backupFormatVersion: BackupConstants.currentBackupFormatVersion,
      schemaVersion: AppDatabase.databaseVersion,
      appVersion: '2.0.0',
      buildNumber: '99',
      exportedAt: DateTime.utc(2026, 1, 15, 8, 30, 0),
      sourceApp: BackupConstants.sourceApp,
      tripCount: 11,
      expenseCount: 22,
      cashTransactionCount: 33,
      cardCount: 44,
      manualExchangeRateCount: 55,
    );

    final envelope = BackupEnvelope(manifest: manifest);
    final restored = BackupEnvelope.fromJson(envelope.toJson()).manifest;

    expect(restored.tripCount, 11);
    expect(restored.expenseCount, 22);
    expect(restored.cashTransactionCount, 33);
    expect(restored.cardCount, 44);
    expect(restored.manualExchangeRateCount, 55);
    expect(restored.appVersion, '2.0.0');
    expect(restored.buildNumber, '99');
  });

  test('rowsFromMaps converts domain maps for export pipelines', () {
    final rows = BackupEnvelope.rowsFromMaps([
      {'id': 'a', 'amount': 1.5},
    ]);

    expect(rows, [
      {'id': 'a', 'amount': 1.5},
    ]);
  });
}
