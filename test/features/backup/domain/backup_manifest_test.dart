import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_format_compatibility.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';

void main() {
  final exportedAt = DateTime.utc(2026, 6, 1, 12, 0, 0);

  BackupManifest buildManifest({
    int backupFormatVersion = BackupConstants.currentBackupFormatVersion,
    int tripCount = 2,
    int expenseCount = 10,
    int cashTransactionCount = 5,
    int cardCount = 1,
    int manualExchangeRateCount = 3,
  }) {
    return BackupManifest(
      backupFormatVersion: backupFormatVersion,
      schemaVersion: AppDatabase.databaseVersion,
      appVersion: '1.0.0',
      buildNumber: '42',
      exportedAt: exportedAt,
      sourceApp: BackupConstants.sourceApp,
      tripCount: tripCount,
      expenseCount: expenseCount,
      cashTransactionCount: cashTransactionCount,
      cardCount: cardCount,
      manualExchangeRateCount: manualExchangeRateCount,
    );
  }

  test('serializes and deserializes correctly', () {
    final manifest = buildManifest();
    final roundTrip = BackupManifest.fromJson(manifest.toJson());

    expect(roundTrip.backupFormatVersion, BackupConstants.currentBackupFormatVersion);
    expect(roundTrip.schemaVersion, AppDatabase.databaseVersion);
    expect(roundTrip.appVersion, '1.0.0');
    expect(roundTrip.buildNumber, '42');
    expect(roundTrip.exportedAt, exportedAt);
    expect(roundTrip.sourceApp, BackupConstants.sourceApp);
    expect(roundTrip.tripCount, 2);
    expect(roundTrip.expenseCount, 10);
    expect(roundTrip.cashTransactionCount, 5);
    expect(roundTrip.cardCount, 1);
    expect(roundTrip.manualExchangeRateCount, 3);
  });

  test('json round-trip via encode/decode preserves values', () {
    final manifest = buildManifest();
    final decoded = jsonDecode(jsonEncode(manifest.toJson())) as Map<String, dynamic>;
    final roundTrip = BackupManifest.fromJson(decoded);

    expect(roundTrip.tripCount, 2);
    expect(roundTrip.exportedAt, exportedAt);
  });

  test('metadata counts are preserved', () {
    final manifest = buildManifest(
      tripCount: 7,
      expenseCount: 99,
      cashTransactionCount: 12,
      cardCount: 4,
      manualExchangeRateCount: 6,
    );

    final restored = BackupManifest.fromJson(manifest.toJson());

    expect(restored.tripCount, 7);
    expect(restored.expenseCount, 99);
    expect(restored.cashTransactionCount, 12);
    expect(restored.cardCount, 4);
    expect(restored.manualExchangeRateCount, 6);
  });

  test('unsupported future backupFormatVersion is detected', () {
    expect(BackupFormatCompatibility.isSupportedBackupFormatVersion(1), isTrue);
    expect(BackupFormatCompatibility.isSupportedBackupFormatVersion(2), isFalse);
    expect(BackupFormatCompatibility.isSupportedBackupFormatVersion(999), isFalse);
  });
}
