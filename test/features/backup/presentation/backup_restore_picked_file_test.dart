import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/backup/data/backup_file_reader.dart';
import 'package:travel_expenses/features/backup/domain/backup_restore_failure.dart';
import 'package:travel_expenses/features/backup/presentation/backup_restore_picked_file.dart';

void main() {
  group('readRestorePickedFileBytes', () {
    test('uses bytes when available', () async {
      final bytes = Uint8List.fromList([123, 125]);
      final file = PlatformFile(
        name: 'backup.clbackup',
        size: 2,
        bytes: bytes,
      );

      final result = await readRestorePickedFileBytes(file);

      expect(result, bytes);
    });

    test('reads from path when bytes are null', () async {
      final tempDir = await Directory.systemTemp.createTemp('restore_pick_');
      addTearDown(() => tempDir.delete(recursive: true));

      final path = '${tempDir.path}/backup.clbackup';
      const content = '{"backup":true}';
      await File(path).writeAsString(content);

      final file = PlatformFile(
        name: 'backup.clbackup',
        size: content.length,
        path: path,
      );

      final result = await readRestorePickedFileBytes(file);

      expect(result, utf8.encode(content));
    });

    test('returns null when bytes and path are unavailable', () async {
      final file = PlatformFile(
        name: 'backup.clbackup',
        size: 0,
      );

      final result = await readRestorePickedFileBytes(file);

      expect(result, isNull);
    });

    test('prefers bytes over path when both are present', () async {
      final tempDir = await Directory.systemTemp.createTemp('restore_pick_');
      addTearDown(() => tempDir.delete(recursive: true));

      final path = '${tempDir.path}/backup.clbackup';
      await File(path).writeAsString('from-disk');

      final bytes = Uint8List.fromList([1, 2, 3]);
      final file = PlatformFile(
        name: 'backup.clbackup',
        size: 3,
        bytes: bytes,
        path: path,
      );

      final result = await readRestorePickedFileBytes(file);

      expect(result, bytes);
    });
  });

  test('invalid JSON is a restore parse failure, not a missing file', () {
    expect(
      () => const BackupFileReader().readJson(
        fileName: 'backup.clbackup',
        contents: '{not valid json',
      ),
      throwsA(
        isA<BackupRestoreException>().having(
          (error) => error.kind,
          'kind',
          BackupRestoreFailureKind.corruptBackup,
        ),
      ),
    );
  });
}
