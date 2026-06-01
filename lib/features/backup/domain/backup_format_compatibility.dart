import 'backup_constants.dart';

/// Read-side checks for backup documents produced by this or future app versions.
abstract final class BackupFormatCompatibility {
  static bool isSupportedBackupFormatVersion(int backupFormatVersion) {
    return backupFormatVersion == BackupConstants.currentBackupFormatVersion;
  }
}
