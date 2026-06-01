import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';
import 'package:travel_expenses/features/backup/domain/backup_restore_validator.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';

void main() {
  const validator = BackupRestoreValidator();

  BackupManifest manifest({
    int tripCount = 1,
    int expenseCount = 0,
    int cashTransactionCount = 0,
    int cardCount = 0,
    int manualExchangeRateCount = 0,
    int schemaVersion = AppDatabase.databaseVersion,
    String sourceApp = BackupConstants.sourceApp,
  }) {
    return BackupManifest(
      backupFormatVersion: BackupConstants.currentBackupFormatVersion,
      schemaVersion: schemaVersion,
      appVersion: '1.0.0',
      buildNumber: '1',
      exportedAt: DateTime.utc(2026, 6, 1),
      sourceApp: sourceApp,
      tripCount: tripCount,
      expenseCount: expenseCount,
      cashTransactionCount: cashTransactionCount,
      cardCount: cardCount,
      manualExchangeRateCount: manualExchangeRateCount,
    );
  }

  BackupEnvelope validEnvelope({
    BackupManifest? manifestOverride,
    List<Map<String, dynamic>>? trips,
    List<Map<String, dynamic>>? expenses,
    List<Map<String, dynamic>>? cards,
    List<Map<String, dynamic>>? cashTransactions,
    List<Map<String, dynamic>>? manualExchangeRates,
  }) {
    final tripsRows =
        trips ??
        [
          {'id': 'trip-1', 'name': 'Tokyo'},
        ];
    return BackupEnvelope(
      manifest: manifestOverride ??
          manifest(
            expenseCount: expenses?.length ?? 0,
            cashTransactionCount: cashTransactions?.length ?? 0,
            cardCount: cards?.length ?? 0,
            manualExchangeRateCount: manualExchangeRates?.length ?? 0,
          ),
      trips: tripsRows,
      expenses: expenses ?? const [],
      cards: cards ?? const [],
      cashTransactions: cashTransactions ?? const [],
      manualExchangeRates: manualExchangeRates ?? const [],
    );
  }

  group('manifest validation', () {
    test('rejects unknown source_app', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(sourceApp: 'OtherApp'),
        ),
      );

      expect(result.isValid, isFalse);
      expect(result.issues.single.code, 'invalid_source_app');
    });
  });

  group('count validation', () {
    test('rejects manifest count mismatch', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(tripCount: 2),
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.where((issue) => issue.code == 'count_mismatch'),
        isNotEmpty,
      );
    });
  });

  group('duplicate ID validation', () {
    test('rejects duplicate trip ids', () {
      final result = validator.validate(
        validEnvelope(
          trips: [
            {'id': 'trip-1', 'name': 'A'},
            {'id': 'trip-1', 'name': 'B'},
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'duplicate_id'),
        isTrue,
      );
    });

    test('rejects duplicate expense ids', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(expenseCount: 2),
          expenses: [
            {'id': 'exp-1', 'trip_id': 'trip-1', 'payment_method': 'Cash'},
            {'id': 'exp-1', 'trip_id': 'trip-1', 'payment_method': 'Cash'},
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'duplicate_id'),
        isTrue,
      );
    });
  });

  group('schema gate', () {
    test('rejects newer schema version', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(
            schemaVersion: AppDatabase.databaseVersion + 1,
          ),
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'unsupported_schema_version'),
        isTrue,
      );
    });
  });

  group('referential integrity', () {
    test('rejects expense with missing trip', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(expenseCount: 1),
          expenses: [
            {
              'id': 'exp-1',
              'trip_id': 'missing-trip',
              'payment_method': 'Cash',
              'source': 'manual',
            },
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'missing_trip_reference'),
        isTrue,
      );
    });

    test('rejects cash transaction with missing expense reference', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(cashTransactionCount: 1),
          cashTransactions: [
            {
              'id': 'cash-1',
              'trip_id': 'trip-1',
              'expense_id': 'missing-expense',
              'type': CashTransactionType.cashExpenseDeduction.value,
            },
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'missing_expense_reference'),
        isTrue,
      );
    });

    test('rejects expense with missing card reference', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(expenseCount: 1),
          expenses: [
            {
              'id': 'exp-1',
              'trip_id': 'trip-1',
              'card_profile_id': 99,
              'payment_method': 'Credit Card',
              'source': 'manual',
            },
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'missing_card_reference'),
        isTrue,
      );
    });
  });

  group('unknown enum protection', () {
    test('rejects unknown cash transaction type', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(cashTransactionCount: 1),
          cashTransactions: [
            {
              'id': 'cash-1',
              'trip_id': 'trip-1',
              'type': 'future_transaction_type',
            },
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'unknown_enum'),
        isTrue,
      );
    });

    test('rejects unknown payment method', () {
      final result = validator.validate(
        validEnvelope(
          manifestOverride: manifest(expenseCount: 1),
          expenses: [
            {
              'id': 'exp-1',
              'trip_id': 'trip-1',
              'payment_method': 'Crypto',
              'source': 'manual',
            },
          ],
        ),
      );

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'unknown_enum'),
        isTrue,
      );
    });
  });

  group('validateJson strict parsing', () {
    test('fails when required array key is missing', () {
      final json = validEnvelope().toJson()..remove(BackupEnvelope.tripsKey);

      final result = validator.validateJson(json);

      expect(result.isValid, isFalse);
      expect(
        result.issues.any((issue) => issue.code == 'invalid_json_shape'),
        isTrue,
      );
    });
  });
}
