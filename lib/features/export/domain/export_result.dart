class ExportResult {
  const ExportResult({
    required this.fileName,
    required this.filePath,
    required this.rowCount,
  });

  final String fileName;
  final String filePath;
  final int rowCount;
}