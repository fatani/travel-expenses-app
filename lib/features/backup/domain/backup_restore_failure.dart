import 'backup_restore_validation_issue.dart';

/// User-facing restore failure categories mapped to localized copy.
enum BackupRestoreFailureKind {
  invalidBackupFile,
  unsupportedBackupVersion,
  unsupportedSchemaVersion,
  corruptBackup,
  restoreFailed,
}

/// Thrown when backup parsing, validation, or restore cannot proceed safely.
class BackupRestoreException implements Exception {
  const BackupRestoreException(this.kind, {this.issues = const []});

  final BackupRestoreFailureKind kind;
  final List<BackupRestoreValidationIssue> issues;

  @override
  String toString() => 'BackupRestoreException($kind, issues: $issues)';
}
