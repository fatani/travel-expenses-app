import 'backup_constants.dart';

/// Read-side checks for backup documents produced by this or future app versions.
abstract final class BackupFormatCompatibility {
  static bool isSupportedBackupFormatVersion(int backupFormatVersion) {
    return backupFormatVersion == BackupConstants.currentBackupFormatVersion;
  }

  /// Whether a backup [schemaVersion] may be restored by this app build.
  ///
  /// * backup schema > current schema → reject (app must be updated first)
  /// * backup schema == current schema → allow
  /// * backup schema < current schema → allow (migrations are out of scope)
  static bool isSupportedSchemaVersion(int backupSchemaVersion) {
    return backupSchemaVersion <= BackupConstants.currentSchemaVersion;
  }
}
