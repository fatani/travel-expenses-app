import 'backup_envelope.dart';

/// Validated backup metadata shown before the user confirms a full replace restore.
class BackupRestorePreview {
  const BackupRestorePreview({required this.envelope});

  final BackupEnvelope envelope;

  DateTime get exportedAt => envelope.manifest.exportedAt;

  int get schemaVersion => envelope.manifest.schemaVersion;

  int get tripCount => envelope.manifest.tripCount;

  int get expenseCount => envelope.manifest.expenseCount;

  int get cashTransactionCount => envelope.manifest.cashTransactionCount;

  int get cardCount => envelope.manifest.cardCount;

  int get manualExchangeRateCount => envelope.manifest.manualExchangeRateCount;
}
