import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/domain/backup_format_compatibility.dart';

void main() {
  group('isSupportedSchemaVersion', () {
    test('allows equal schema version', () {
      expect(
        BackupFormatCompatibility.isSupportedSchemaVersion(
          AppDatabase.databaseVersion,
        ),
        isTrue,
      );
    });

    test('allows older schema version', () {
      expect(
        BackupFormatCompatibility.isSupportedSchemaVersion(
          AppDatabase.databaseVersion - 1,
        ),
        isTrue,
      );
    });

    test('rejects newer schema version', () {
      expect(
        BackupFormatCompatibility.isSupportedSchemaVersion(
          AppDatabase.databaseVersion + 1,
        ),
        isFalse,
      );
    });
  });
}
