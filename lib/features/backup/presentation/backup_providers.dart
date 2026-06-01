import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../data/backup_data_collector.dart';
import '../data/backup_export_service.dart';

final backupDataCollectorProvider = Provider<BackupDataCollector>((ref) {
  return BackupDataCollector(ref.watch(appDatabaseProvider));
});

final backupExportServiceProvider = Provider<BackupExportService>((ref) {
  return BackupExportService(
    collector: ref.watch(backupDataCollectorProvider),
  );
});
