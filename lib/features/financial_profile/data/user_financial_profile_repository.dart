import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/user_financial_profile.dart';

class UserFinancialProfileRepository {
  UserFinancialProfileRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<UserFinancialProfile?> loadProfile() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.userFinancialProfileTable,
      where: 'id = ?',
      whereArgs: [UserFinancialProfile.singletonId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return UserFinancialProfile.fromMap(rows.first);
  }

  Future<UserFinancialProfile> saveProfile(UserFinancialProfile profile) async {
    final db = await _appDatabase.database;
    await db.insert(
      AppDatabase.userFinancialProfileTable,
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return profile;
  }
}
