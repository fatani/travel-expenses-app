import '../domain/backup_export_result.dart';
import 'backup_data_collector.dart';
import 'backup_envelope_builder.dart';
import 'backup_file_writer.dart';
import 'backup_manifest_builder.dart';

/// Orchestrates backup export: collect → manifest → envelope → file.
class BackupExportService {
  BackupExportService({
    required BackupDataCollector collector,
    BackupManifestBuilder? manifestBuilder,
    BackupEnvelopeBuilder? envelopeBuilder,
    BackupFileWriter? fileWriter,
  }) : _collector = collector,
       _manifestBuilder = manifestBuilder ?? const BackupManifestBuilder(),
       _envelopeBuilder = envelopeBuilder ?? const BackupEnvelopeBuilder(),
       _fileWriter = fileWriter ?? BackupFileWriter();

  final BackupDataCollector _collector;
  final BackupManifestBuilder _manifestBuilder;
  final BackupEnvelopeBuilder _envelopeBuilder;
  final BackupFileWriter _fileWriter;

  Future<BackupExportResult> export({DateTime? exportedAt}) async {
    final data = await _collector.collect();
    final at = (exportedAt ?? DateTime.now()).toUtc();
    final manifest = _manifestBuilder.build(data, exportedAt: at);
    final envelope = _envelopeBuilder.build(manifest: manifest, data: data);
    return _fileWriter.write(envelope, exportedAt: at);
  }
}
