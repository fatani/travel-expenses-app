class BackupExportResult {
  const BackupExportResult({
    required this.fileName,
    required this.filePath,
    required this.byteLength,
  });

  final String fileName;
  final String filePath;
  final int byteLength;
}
