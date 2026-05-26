import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/integrity/data_integrity.dart';
import '../domain/trip.dart';

class TripRepository {
  TripRepository(this._appDatabase, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _appDatabase;
  final Uuid _uuid;

  Future<Trip> createTrip(Trip trip) async {
    DataIntegrity.requireTripCurrencies(
      baseCurrency: trip.baseCurrency,
      destinationCurrency: trip.destinationCurrency,
      homeCurrencySnapshot: trip.homeCurrencySnapshot,
      budgetCurrency: trip.budgetCurrency,
    );

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

    return _parseTripRows(rows);
  }

  Future<Trip?> getTripById(String id) async {
    if (id.trim().isEmpty) {
      return null;
    }

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

    return Trip.tryFromMap(rows.first);
  }

  Future<Trip> updateTrip(Trip trip) async {
    DataIntegrity.requireTripCurrencies(
      baseCurrency: trip.baseCurrency,
      destinationCurrency: trip.destinationCurrency,
      homeCurrencySnapshot: trip.homeCurrencySnapshot,
      budgetCurrency: trip.budgetCurrency,
    );

    final db = await _appDatabase.database;
    final entity = trip.copyWith(updatedAt: DateTime.now().toUtc());

    final updated = await db.update(
      AppDatabase.tripsTable,
      entity.toMap(),
      where: 'id = ?',
      whereArgs: [entity.id],
    );
    if (updated == 0) {
      throw const DataIntegrityException('tripNotFound');
    }

    return entity;
  }

  Future<void> deleteTrip(String id) async {
    DataIntegrity.requireNonEmptyId(id, field: 'tripId');
    final db = await _appDatabase.database;
    await db.transaction((txn) async {
      await txn.delete(
        AppDatabase.manualExchangeRatesTable,
        where: 'trip_id = ?',
        whereArgs: [id],
      );
      final deleted = await txn.delete(
        AppDatabase.tripsTable,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (deleted == 0) {
        throw const DataIntegrityException('tripNotFound');
      }
    });
  }

  List<Trip> _parseTripRows(List<Map<String, Object?>> rows) {
    final trips = <Trip>[];
    for (final row in rows) {
      final trip = Trip.tryFromMap(row);
      if (trip != null) {
        trips.add(trip);
      }
    }
    return trips;
  }
}
