import '../../../core/database/app_database.dart';
import '../domain/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<void> initializeDefaults() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.settingsTable,
      where: 'id = ?',
      whereArgs: [AppSettings.singletonId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return;
    }

    await db.insert(AppDatabase.settingsTable, AppSettings.defaults().toMap());
  }

  Future<AppSettings> loadSettings() async {
    await initializeDefaults();

    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.settingsTable,
      where: 'id = ?',
      whereArgs: [AppSettings.singletonId],
      limit: 1,
    );

    return AppSettings.fromMap(rows.first);
  }

  Future<AppSettings> saveSettings(AppSettings settings) async {
    await initializeDefaults();

    final db = await _appDatabase.database;
    final current = await loadSettings();
    final entity = settings.copyWith(
      id: AppSettings.singletonId,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );

    await db.update(
      AppDatabase.settingsTable,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [AppSettings.singletonId],
    );

    return entity;
  }
}
