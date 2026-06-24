import 'backup_constants.dart';
import 'backup_envelope.dart';
import 'backup_format_compatibility.dart';
import 'backup_persisted_enums.dart';
import 'backup_restore_validation_issue.dart';

/// Pre-restore safety gates for CalmLedger JSON backups.
///
/// Does not touch the database. Restore flows must pass [validate] before any
/// write transaction runs.
class BackupRestoreValidator {
  const BackupRestoreValidator();

  BackupRestoreValidationResult validate(BackupEnvelope envelope) {
    final issues = <BackupRestoreValidationIssue>[];

    _validateManifest(envelope, issues);
    _validateFormatCompatibility(envelope, issues);
    _validateCounts(envelope, issues);
    _validateDuplicateIds(envelope, issues);
    _validateReferentialIntegrity(envelope, issues);
    _validatePersistedEnums(envelope, issues);

    if (issues.isEmpty) {
      return BackupRestoreValidationResult.success();
    }
    return BackupRestoreValidationResult.failure(issues);
  }

  /// Strict JSON parse + [validate].
  BackupRestoreValidationResult validateJson(Map<String, dynamic> json) {
    try {
      final envelope = BackupEnvelope.fromJsonStrict(json);
      return validate(envelope);
    } on FormatException catch (error) {
      return BackupRestoreValidationResult.failure([
        BackupRestoreValidationIssue(
          code: 'invalid_json_shape',
          message: error.message,
        ),
      ]);
    }
  }

  void _validateManifest(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    final manifest = envelope.manifest;

    if (manifest.sourceApp != BackupConstants.sourceApp) {
      issues.add(
        BackupRestoreValidationIssue(
          code: 'invalid_source_app',
          message:
              'Unsupported source_app: ${manifest.sourceApp}',
        ),
      );
    }

    if (manifest.exportedAt.isAfter(DateTime.now().toUtc().add(
      const Duration(minutes: 5),
    ))) {
      issues.add(
        const BackupRestoreValidationIssue(
          code: 'invalid_exported_at',
          message: 'exported_at is in the future',
        ),
      );
    }
  }

  void _validateFormatCompatibility(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    final manifest = envelope.manifest;

    if (!BackupFormatCompatibility.isSupportedBackupFormatVersion(
      manifest.backupFormatVersion,
    )) {
      issues.add(
        BackupRestoreValidationIssue(
          code: 'unsupported_backup_format_version',
          message:
              'Unsupported backup_format_version: ${manifest.backupFormatVersion}',
        ),
      );
    }

    if (!BackupFormatCompatibility.isSupportedSchemaVersion(
      manifest.schemaVersion,
    )) {
      issues.add(
        BackupRestoreValidationIssue(
          code: 'unsupported_schema_version',
          message:
              'Backup schema_version ${manifest.schemaVersion} is newer than app schema ${BackupConstants.currentSchemaVersion}',
        ),
      );
    }
  }

  void _validateCounts(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    final manifest = envelope.manifest;
    _expectCount(
      issues,
      field: 'trip_count',
      expected: manifest.tripCount,
      actual: envelope.trips.length,
    );
    _expectCount(
      issues,
      field: 'expense_count',
      expected: manifest.expenseCount,
      actual: envelope.expenses.length,
    );
    _expectCount(
      issues,
      field: 'cash_transaction_count',
      expected: manifest.cashTransactionCount,
      actual: envelope.cashTransactions.length,
    );
    _expectCount(
      issues,
      field: 'card_count',
      expected: manifest.cardCount,
      actual: envelope.cards.length,
    );
    _expectCount(
      issues,
      field: 'manual_exchange_rate_count',
      expected: manifest.manualExchangeRateCount,
      actual: envelope.manualExchangeRates.length,
    );
    _expectCount(
      issues,
      field: 'refund_count',
      expected: manifest.refundCount,
      actual: envelope.expenseRefunds.length,
    );
  }

  void _expectCount(
    List<BackupRestoreValidationIssue> issues, {
    required String field,
    required int expected,
    required int actual,
  }) {
    if (expected != actual) {
      issues.add(
        BackupRestoreValidationIssue(
          code: 'count_mismatch',
          message: 'Manifest $field ($expected) does not match payload ($actual)',
        ),
      );
    }
  }

  void _validateDuplicateIds(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    _expectUniqueStringIds(
      issues,
      collection: 'trips',
      rows: envelope.trips,
      idKey: 'id',
    );
    _expectUniqueStringIds(
      issues,
      collection: 'expenses',
      rows: envelope.expenses,
      idKey: 'id',
    );
    _expectUniqueIntIds(
      issues,
      collection: 'cards',
      rows: envelope.cards,
      idKey: 'id',
    );
    _expectUniqueStringIds(
      issues,
      collection: 'cash_transactions',
      rows: envelope.cashTransactions,
      idKey: 'id',
    );
    _expectUniqueManualExchangeRateKeys(
      issues,
      rows: envelope.manualExchangeRates,
    );
    _expectUniqueStringIds(
      issues,
      collection: 'expense_refunds',
      rows: envelope.expenseRefunds,
      idKey: 'id',
    );
  }

  void _expectUniqueStringIds(
    List<BackupRestoreValidationIssue> issues, {
    required String collection,
    required List<Map<String, dynamic>> rows,
    required String idKey,
  }) {
    final seen = <String>{};
    for (final row in rows) {
      final id = row[idKey];
      if (id is! String || id.isEmpty) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'invalid_id',
            message: '$collection row missing string $idKey',
          ),
        );
        continue;
      }
      if (!seen.add(id)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'duplicate_id',
            message: 'Duplicate $idKey in $collection: $id',
          ),
        );
      }
    }
  }

  void _expectUniqueIntIds(
    List<BackupRestoreValidationIssue> issues, {
    required String collection,
    required List<Map<String, dynamic>> rows,
    required String idKey,
  }) {
    final seen = <int>{};
    for (final row in rows) {
      final id = row[idKey];
      if (id is! int) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'invalid_id',
            message: '$collection row missing int $idKey',
          ),
        );
        continue;
      }
      if (!seen.add(id)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'duplicate_id',
            message: 'Duplicate $idKey in $collection: $id',
          ),
        );
      }
    }
  }

  void _expectUniqueManualExchangeRateKeys(
    List<BackupRestoreValidationIssue> issues, {
    required List<Map<String, dynamic>> rows,
  }) {
    final seen = <String>{};
    for (final row in rows) {
      final tripId = row['trip_id'] as String?;
      final from = row['from_currency'] as String?;
      final to = row['to_currency'] as String?;
      if (tripId == null || from == null || to == null) {
        issues.add(
          const BackupRestoreValidationIssue(
            code: 'invalid_manual_exchange_rate',
            message: 'manual_exchange_rates row missing composite key fields',
          ),
        );
        continue;
      }
      final key = '$tripId|$from|$to';
      if (!seen.add(key)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'duplicate_id',
            message: 'Duplicate manual_exchange_rates key: $key',
          ),
        );
      }
    }
  }

  void _validateReferentialIntegrity(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    final tripIds = envelope.trips.map((row) => row['id'] as String?).toSet();
    final expenseIds =
        envelope.expenses.map((row) => row['id'] as String?).toSet();
    final cardIds = envelope.cards.map((row) => row['id'] as int?).toSet();

    for (final expense in envelope.expenses) {
      final tripId = expense['trip_id'] as String?;
      if (tripId == null || !tripIds.contains(tripId)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_trip_reference',
            message: 'expense ${expense['id']} references missing trip_id $tripId',
          ),
        );
      }

      final cardId = expense['card_profile_id'];
      if (cardId != null && !cardIds.contains(cardId as int)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_card_reference',
            message:
                'expense ${expense['id']} references missing card_profile_id $cardId',
          ),
        );
      }
    }

    for (final transaction in envelope.cashTransactions) {
      final tripId = transaction['trip_id'] as String?;
      if (tripId == null || !tripIds.contains(tripId)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_trip_reference',
            message:
                'cash_transaction ${transaction['id']} references missing trip_id $tripId',
          ),
        );
      }

      final expenseId = transaction['expense_id'];
      if (expenseId != null && !expenseIds.contains(expenseId as String)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_expense_reference',
            message:
                'cash_transaction ${transaction['id']} references missing expense_id $expenseId',
          ),
        );
      }
    }

    for (final rate in envelope.manualExchangeRates) {
      final tripId = rate['trip_id'] as String?;
      if (tripId == null || !tripIds.contains(tripId)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_trip_reference',
            message:
                'manual_exchange_rates row references missing trip_id $tripId',
          ),
        );
      }
    }

    for (final refund in envelope.expenseRefunds) {
      final tripId = refund['trip_id'] as String?;
      if (tripId == null || !tripIds.contains(tripId)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_trip_reference',
            message:
                'expense_refunds row ${refund['id']} references missing trip_id $tripId',
          ),
        );
      }

      final expenseId = refund['expense_id'];
      if (expenseId != null && !expenseIds.contains(expenseId as String)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'missing_expense_reference',
            message:
                'expense_refunds row ${refund['id']} references missing expense_id $expenseId',
          ),
        );
      }
    }
  }

  void _validatePersistedEnums(
    BackupEnvelope envelope,
    List<BackupRestoreValidationIssue> issues,
  ) {
    for (final transaction in envelope.cashTransactions) {
      final type = transaction['type'] as String?;
      if (!BackupPersistedEnums.isKnownCashTransactionType(type)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported cash_transactions.type: $type (id=${transaction['id']})',
          ),
        );
      }

      final isReversed = transaction['is_reversed'];
      if (isReversed != null && isReversed != 0 && isReversed != 1) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'invalid_field',
            message:
                'cash_transactions.is_reversed must be 0 or 1 (id=${transaction['id']}, got=$isReversed)',
          ),
        );
      }
    }

    for (final expense in envelope.expenses) {
      final paymentMethod = expense['payment_method'] as String?;
      if (!BackupPersistedEnums.isKnownExpensePaymentMethod(paymentMethod)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expenses.payment_method: $paymentMethod (id=${expense['id']})',
          ),
        );
      }

      final paymentNetwork = expense['payment_network'] as String?;
      if (!BackupPersistedEnums.isKnownExpensePaymentNetwork(paymentNetwork)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expenses.payment_network: $paymentNetwork (id=${expense['id']})',
          ),
        );
      }

      final paymentChannel = expense['payment_channel'] as String?;
      if (!BackupPersistedEnums.isKnownExpensePaymentChannel(paymentChannel)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expenses.payment_channel: $paymentChannel (id=${expense['id']})',
          ),
        );
      }

      final category = expense['category'] as String?;
      if (!BackupPersistedEnums.isKnownExpenseCategory(category)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expenses.category: $category (id=${expense['id']})',
          ),
        );
      }

      final source = expense['source'] as String?;
      if (!BackupPersistedEnums.isKnownExpenseSource(source)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expenses.source: $source (id=${expense['id']})',
          ),
        );
      }

      final isReversed = expense['is_reversed'];
      if (isReversed != null && isReversed != 0 && isReversed != 1) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'invalid_field',
            message:
                'expenses.is_reversed must be 0 or 1 (id=${expense['id']}, got=$isReversed)',
          ),
        );
      }
    }

    for (final refund in envelope.expenseRefunds) {
      final destination = refund['destination'] as String?;
      if (!BackupPersistedEnums.isKnownRefundDestination(destination)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported expense_refunds.destination: $destination (id=${refund['id']})',
          ),
        );
      }

      final isReversed = refund['is_reversed'];
      if (isReversed != 0 && isReversed != 1) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'invalid_field',
            message:
                'expense_refunds.is_reversed must be 0 or 1 (id=${refund['id']}, got=$isReversed)',
          ),
        );
      }
    }

    for (final card in envelope.cards) {
      final bank = card['bank_name'] as String?;
      if (!BackupPersistedEnums.isKnownCardBank(bank)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported cards.bank_name: $bank (id=${card['id']})',
          ),
        );
      }

      final network = card['card_network'] as String?;
      if (!BackupPersistedEnums.isKnownCardNetwork(network)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message:
                'Unsupported cards.card_network: $network (id=${card['id']})',
          ),
        );
      }

      final tier = card['card_tier'] as String?;
      if (!BackupPersistedEnums.isKnownCardTier(tier)) {
        issues.add(
          BackupRestoreValidationIssue(
            code: 'unknown_enum',
            message: 'Unsupported cards.card_tier: $tier (id=${card['id']})',
          ),
        );
      }
    }
  }
}
