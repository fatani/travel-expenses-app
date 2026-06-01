import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/backup_constants.dart';
import '../domain/backup_envelope.dart';
import '../domain/backup_export_result.dart';

typedef BackupDirectoryProvider = Future<Directory> Function();

/// Writes a UTF-8 JSON [BackupEnvelope] to a temporary `.clbackup` file.
class BackupFileWriter {
  BackupFileWriter({BackupDirectoryProvider? directoryProvider})
    : _directoryProvider = directoryProvider ?? getTemporaryDirectory;

  final BackupDirectoryProvider _directoryProvider;

  Future<BackupExportResult> write(
    BackupEnvelope envelope, {
    DateTime? exportedAt,
  }) async {
    final at = (exportedAt ?? envelope.manifest.exportedAt).toUtc();
    final fileName = buildFileName(at);
    final directory = await _directoryProvider();
    final filePath = p.join(directory.path, fileName);
    final json = jsonEncode(envelope.toJson());
    final bytes = utf8.encode(json);
    final file = File(filePath);

    await file.writeAsBytes(bytes, flush: true);

    return BackupExportResult(
      fileName: fileName,
      filePath: filePath,
      byteLength: bytes.length,
    );
  }

  static String buildFileName(DateTime exportedAt) {
    final stamp = DateFormat('yyyy-MM-dd-HHmmss').format(exportedAt.toUtc());
    return 'calmledger-backup-$stamp${BackupConstants.fileExtension}';
  }
}
