import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';
import 'package:travel_expenses/features/backup/domain/backup_persisted_enums.dart';

/// ATM fee expenses (channel 'ATM Withdrawal Fee', category 'Fees') carry a
/// source_ref link. This proves the backup layer treats them as known and that
/// the new source-ref fields survive the envelope JSON round-trip.
void main() {
  group('backup recognizes ATM fee enums', () {
    test("'ATM Withdrawal Fee' is a known payment channel", () {
      expect(
        BackupPersistedEnums.isKnownExpensePaymentChannel('ATM Withdrawal Fee'),
        isTrue,
      );
    });

    test("'Fees' is a known expense category", () {
      expect(BackupPersistedEnums.isKnownExpenseCategory('Fees'), isTrue);
    });
  });

  group('source ref survives backup JSON round-trip', () {
    test('expense source_ref_type/source_ref_id are preserved', () {
      final envelope = BackupEnvelope(
        manifest: _manifest(),
        expenses: [
          {
            'id': 'fee-1',
            'trip_id': 'trip-1',
            'title': 'ATM Fee',
            'amount': 10.0,
            'currency_code': 'SAR',
            'payment_method': 'Credit Card',
            'payment_channel': 'ATM Withdrawal Fee',
            'category': 'Fees',
            'source_ref_type': 'atm_withdrawal',
            'source_ref_id': 'atm-tx-1',
          },
        ],
      );

      // Round-trip through JSON exactly as export/import does.
      final json = jsonDecode(jsonEncode(envelope.toJson()))
          as Map<String, dynamic>;
      final restored = BackupEnvelope.fromJson(json);

      final fee = restored.expenses.single;
      expect(fee['source_ref_type'], 'atm_withdrawal');
      expect(fee['source_ref_id'], 'atm-tx-1');
    });
  });
}

BackupManifest _manifest() {
  return BackupManifest(
    backupFormatVersion: BackupConstants.currentBackupFormatVersion,
    schemaVersion: AppDatabase.databaseVersion,
    appVersion: '1.0.0',
    buildNumber: '1',
    exportedAt: DateTime.utc(2026, 6, 1),
    sourceApp: BackupConstants.sourceApp,
    tripCount: 1,
    expenseCount: 1,
    cashTransactionCount: 0,
    cardCount: 0,
    manualExchangeRateCount: 0,
  );
}
