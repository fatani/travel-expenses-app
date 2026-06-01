import '../../../core/database/app_database.dart';

/// Stage 1 JSON backup format identifiers and file conventions.
abstract final class BackupConstants {
  static const int currentBackupFormatVersion = 1;

  static const String sourceApp = 'CalmLedger';

  static const String fileExtension = '.clbackup';

  /// SQLite schema version at export time; tied to [AppDatabase.databaseVersion].
  static int get currentSchemaVersion => AppDatabase.databaseVersion;
}
