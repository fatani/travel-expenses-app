import '../domain/backup_app_info.dart';
import '../domain/backup_constants.dart';
import '../domain/backup_manifest.dart';
import 'backup_collected_data.dart';

/// Builds [BackupManifest] metadata from collected database rows.
class BackupManifestBuilder {
  const BackupManifestBuilder();

  BackupManifest build(
    BackupCollectedData data, {
    DateTime? exportedAt,
    String? appVersion,
    String? buildNumber,
  }) {
    final at = (exportedAt ?? DateTime.now()).toUtc();

    return BackupManifest(
      backupFormatVersion: BackupConstants.currentBackupFormatVersion,
      schemaVersion: BackupConstants.currentSchemaVersion,
      appVersion: appVersion ?? BackupAppInfo.appVersion,
      buildNumber: buildNumber ?? BackupAppInfo.buildNumber,
      exportedAt: at,
      sourceApp: BackupConstants.sourceApp,
      tripCount: data.trips.length,
      expenseCount: data.expenses.length,
      cashTransactionCount: data.cashTransactions.length,
      cardCount: data.cards.length,
      manualExchangeRateCount: data.manualExchangeRates.length,
      refundCount: data.expenseRefunds.length,
    );
  }
}
