import 'package:travel_expenses/l10n/app_localizations.dart';

import '../domain/backup_restore_failure.dart';

String backupRestoreFailureMessage(
  AppLocalizations l10n,
  BackupRestoreException error,
) {
  switch (error.kind) {
    case BackupRestoreFailureKind.invalidBackupFile:
      return l10n.backupRestoreInvalidFile;
    case BackupRestoreFailureKind.unsupportedBackupVersion:
      return l10n.backupRestoreUnsupportedBackupVersion;
    case BackupRestoreFailureKind.unsupportedSchemaVersion:
      return l10n.backupRestoreUnsupportedSchemaVersion;
    case BackupRestoreFailureKind.corruptBackup:
      return l10n.backupRestoreCorruptBackup;
    case BackupRestoreFailureKind.restoreFailed:
      return l10n.backupRestoreFailed;
  }
}
