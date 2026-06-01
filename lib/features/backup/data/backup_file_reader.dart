import 'dart:convert';

import '../domain/backup_constants.dart';
import '../domain/backup_restore_failure.dart';

/// Reads CalmLedger `.clbackup` files (UTF-8 JSON only).
class BackupFileReader {
  const BackupFileReader();

  /// Parses [fileName] and [contents] into JSON.
  ///
  /// Rejects non-[BackupConstants.fileExtension] names and invalid JSON.
  Map<String, dynamic> readJson({
    required String fileName,
    required String contents,
  }) {
    if (!fileName.toLowerCase().endsWith(BackupConstants.fileExtension)) {
      throw const BackupRestoreException(
        BackupRestoreFailureKind.invalidBackupFile,
      );
    }

    if (contents.trim().isEmpty) {
      throw const BackupRestoreException(
        BackupRestoreFailureKind.corruptBackup,
      );
    }

    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupRestoreException(
          BackupRestoreFailureKind.corruptBackup,
        );
      }
      return decoded;
    } on FormatException {
      throw const BackupRestoreException(
        BackupRestoreFailureKind.corruptBackup,
      );
    } on BackupRestoreException {
      rethrow;
    } catch (_) {
      throw const BackupRestoreException(
        BackupRestoreFailureKind.corruptBackup,
      );
    }
  }
}
