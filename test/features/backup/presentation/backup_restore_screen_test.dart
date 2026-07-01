import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/backup/presentation/backup_restore_screen.dart';

void main() {
  group('isSupportedRestorePickedFile', () {
    test('.clbackup accepted case-insensitively', () {
      final lower = PlatformFile(name: 'backup.clbackup', size: 0);
      final upper = PlatformFile(name: 'backup.CLBACKUP', size: 0);

      expect(isSupportedRestorePickedFile(lower), isTrue);
      expect(isSupportedRestorePickedFile(upper), isTrue);
    });

    test('.txt/.json rejected', () {
      final txt = PlatformFile(name: 'backup.txt', size: 0);
      final json = PlatformFile(name: 'backup.json', size: 0);

      expect(isSupportedRestorePickedFile(txt), isFalse);
      expect(isSupportedRestorePickedFile(json), isFalse);
    });

    test('path fallback is considered for extension check', () {
      final fromPath = PlatformFile(
        name: 'backup',
        path: '/tmp/my-backup.CLBACKUP',
        size: 0,
      );

      expect(isSupportedRestorePickedFile(fromPath), isTrue);
    });
  });

  test('restore picker uses FileType.any without allowedExtensions', () {
    final source = File(
      'lib/features/backup/presentation/backup_restore_screen.dart',
    ).readAsStringSync();

    expect(source, contains('type: FileType.any'));
    expect(source, isNot(contains('allowedExtensions:')));
  });
}
