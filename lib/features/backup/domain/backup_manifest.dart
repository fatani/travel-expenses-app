/// Metadata describing a CalmLedger JSON backup file.
///
/// Count fields summarize payload rows for pre-restore confirmation UI (later stages).
class BackupManifest {
  const BackupManifest({
    required this.backupFormatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.exportedAt,
    required this.sourceApp,
    required this.tripCount,
    required this.expenseCount,
    required this.cashTransactionCount,
    required this.cardCount,
    required this.manualExchangeRateCount,
  });

  final int backupFormatVersion;
  final int schemaVersion;
  final String appVersion;
  final String buildNumber;
  final DateTime exportedAt;
  final String sourceApp;
  final int tripCount;
  final int expenseCount;
  final int cashTransactionCount;
  final int cardCount;
  final int manualExchangeRateCount;

  Map<String, dynamic> toJson() {
    return {
      'backup_format_version': backupFormatVersion,
      'schema_version': schemaVersion,
      'app_version': appVersion,
      'build_number': buildNumber,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'source_app': sourceApp,
      'trip_count': tripCount,
      'expense_count': expenseCount,
      'cash_transaction_count': cashTransactionCount,
      'card_count': cardCount,
      'manual_exchange_rate_count': manualExchangeRateCount,
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      backupFormatVersion: _readInt(json, 'backup_format_version'),
      schemaVersion: _readInt(json, 'schema_version'),
      appVersion: json['app_version']! as String,
      buildNumber: json['build_number']! as String,
      exportedAt: DateTime.parse(json['exported_at']! as String).toUtc(),
      sourceApp: json['source_app']! as String,
      tripCount: _readInt(json, 'trip_count'),
      expenseCount: _readInt(json, 'expense_count'),
      cashTransactionCount: _readInt(json, 'cash_transaction_count'),
      cardCount: _readInt(json, 'card_count'),
      manualExchangeRateCount: _readInt(json, 'manual_exchange_rate_count'),
    );
  }

  static int _readInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw FormatException('Expected int for $key');
  }
}
