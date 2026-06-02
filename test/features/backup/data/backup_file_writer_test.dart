import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/backup/data/backup_file_writer.dart';
import 'package:travel_expenses/features/backup/domain/backup_constants.dart';
import 'package:travel_expenses/features/backup/domain/backup_envelope.dart';
import 'package:travel_expenses/features/backup/domain/backup_manifest.dart';

class _FakePathProvider extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProvider({
    required this.documentsPath,
    required this.temporaryPath,
  });

  final String documentsPath;
  final String temporaryPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

BackupEnvelope _emptyEnvelope({required DateTime exportedAt}) {
  return BackupEnvelope(
    manifest: BackupManifest(
      backupFormatVersion: BackupConstants.currentBackupFormatVersion,
      schemaVersion: AppDatabase.databaseVersion,
      appVersion: '1.0.0',
      buildNumber: '1',
      exportedAt: exportedAt,
      sourceApp: BackupConstants.sourceApp,
      tripCount: 0,
      expenseCount: 0,
      cashTransactionCount: 0,
      cardCount: 0,
      manualExchangeRateCount: 0,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory injectedDir;
  late Directory fakeDocumentsDir;
  late Directory fakeTemporaryDir;
  late PathProviderPlatform originalPathProvider;

  final exportedAt = DateTime.utc(2026, 6, 1, 14, 30, 45);

  setUp(() async {
    injectedDir = await Directory.systemTemp.createTemp('backup_writer_injected_');
    fakeDocumentsDir =
        await Directory.systemTemp.createTemp('backup_writer_docs_');
    fakeTemporaryDir =
        await Directory.systemTemp.createTemp('backup_writer_temp_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(
      documentsPath: fakeDocumentsDir.path,
      temporaryPath: fakeTemporaryDir.path,
    );
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;

    for (final dir in [injectedDir, fakeDocumentsDir, fakeTemporaryDir]) {
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    }
  });

  test('writes to injected directory provider', () async {
    final writer = BackupFileWriter(
      directoryProvider: () async => injectedDir,
    );

    final result = await writer.write(
      _emptyEnvelope(exportedAt: exportedAt),
      exportedAt: exportedAt,
    );

    expect(result.filePath.startsWith(injectedDir.path), isTrue);
    expect(File(result.filePath).existsSync(), isTrue);
  });

  test('production default uses application documents directory', () async {
    final writer = BackupFileWriter();

    final result = await writer.write(
      _emptyEnvelope(exportedAt: exportedAt),
      exportedAt: exportedAt,
    );

    expect(result.filePath.startsWith(fakeDocumentsDir.path), isTrue);
    expect(result.filePath.startsWith(fakeTemporaryDir.path), isFalse);
  });

  test('file name uses .clbackup extension and timestamp pattern', () async {
    final writer = BackupFileWriter(
      directoryProvider: () async => injectedDir,
    );

    final result = await writer.write(
      _emptyEnvelope(exportedAt: exportedAt),
      exportedAt: exportedAt,
    );

    expect(result.fileName, 'calmledger-backup-2026-06-01-143045.clbackup');
    expect(result.fileName.endsWith(BackupConstants.fileExtension), isTrue);
  });

  test('written file is valid UTF-8 JSON', () async {
    final writer = BackupFileWriter(
      directoryProvider: () async => injectedDir,
    );

    final result = await writer.write(
      _emptyEnvelope(exportedAt: exportedAt),
      exportedAt: exportedAt,
    );

    final bytes = await File(result.filePath).readAsBytes();
    final decoded = utf8.decode(bytes);
    final json = jsonDecode(decoded) as Map<String, dynamic>;

    expect(json['manifest'], isA<Map<String, dynamic>>());
    expect(
      (json['manifest'] as Map<String, dynamic>)['source_app'],
      BackupConstants.sourceApp,
    );
  });
}
