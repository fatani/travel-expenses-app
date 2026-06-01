import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../data/backup_data_collector.dart';
import '../data/backup_export_service.dart';
import '../data/backup_restore_service.dart';

final backupDataCollectorProvider = Provider<BackupDataCollector>((ref) {
  return BackupDataCollector(ref.watch(appDatabaseProvider));
});

final backupExportServiceProvider = Provider<BackupExportService>((ref) {
  return BackupExportService(
    collector: ref.watch(backupDataCollectorProvider),
  );
});

final backupRestoreServiceProvider = Provider<BackupRestoreService>((ref) {
  return BackupRestoreService(
    appDatabase: ref.watch(appDatabaseProvider),
  );
});
