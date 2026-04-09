import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/trip.dart';

class TripRepository {
  TripRepository(this._appDatabase, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<Trip> createTrip(Trip trip) async {
    final db = await _appDatabase.database;
    final now = DateTime.now().toUtc();
    final entity = trip.copyWith(
      id: trip.id.isEmpty ? _uuid.v4() : trip.id,
      updatedAt: now,
    );

    await db.insert(
      AppDatabase.tripsTable,
      entity.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    return entity;
  }

  Future<List<Trip>> getTrips() async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tripsTable,
      orderBy: 'start_date ASC, created_at DESC',
    );

    return rows.map(Trip.fromMap).toList();
  }

  Future<Trip?> getTripById(String id) async {
    final db = await _appDatabase.database;
    final rows = await db.query(
      AppDatabase.tripsTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Trip.fromMap(rows.first);
  }

  Future<Trip> updateTrip(Trip trip) async {
    final db = await _appDatabase.database;
    final entity = trip.copyWith(updatedAt: DateTime.now().toUtc());

    await db.update(
      AppDatabase.tripsTable,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );

    return entity;
  }

  Future<void> deleteTrip(String id) async {
    final db = await _appDatabase.database;
    await db.delete(AppDatabase.tripsTable, where: 'id = ?', whereArgs: [id]);
  }
}
