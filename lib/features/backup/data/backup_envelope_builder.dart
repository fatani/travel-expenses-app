import '../domain/backup_envelope.dart';
import '../domain/backup_manifest.dart';
import 'backup_collected_data.dart';

/// Assembles a [BackupEnvelope] from manifest metadata and collected rows.
class BackupEnvelopeBuilder {
  const BackupEnvelopeBuilder();

  BackupEnvelope build({
    required BackupManifest manifest,
    required BackupCollectedData data,
  }) {
    return BackupEnvelope(
      manifest: manifest,
      userFinancialProfile: data.userFinancialProfile,
      settings: data.settings,
      cards: data.cards,
      trips: data.trips,
      manualExchangeRates: data.manualExchangeRates,
      expenses: data.expenses,
      cashTransactions: data.cashTransactions,
      expenseRefunds: data.expenseRefunds,
    );
  }
}
