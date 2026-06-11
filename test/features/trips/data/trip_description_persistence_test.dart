import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late TripRepository tripRepository;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'trip_description');
    tripRepository = TripRepository(appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<List<Map<String, Object?>>> tripsTableInfo() async {
    final db = await appDatabase.database;
    return db.rawQuery('PRAGMA table_info(${AppDatabase.tripsTable})');
  }

  group('Sprint UX-1A — trip description persistence', () {
    test('schema contains description column', () async {
      final columns = (await tripsTableInfo())
          .map((row) => row['name'] as String)
          .toSet();

      expect(columns, contains('description'));

      final descriptionColumn = (await tripsTableInfo()).firstWhere(
        (row) => row['name'] == 'description',
      );
      expect(descriptionColumn['type'], 'TEXT');
      expect(descriptionColumn['notnull'], 0);
    });

    test('migration preserves existing trips with null description', () async {
      final databaseFileName =
          'trip_description_migration_${DateTime.now().microsecondsSinceEpoch}.db';
      final databasesPath = await getDatabasesPath();
      final databasePath = p.join(databasesPath, databaseFileName);

      const legacyTripId = 'legacy-trip-ux1a';
      final createdAt = DateTime.utc(2026, 1, 1).toIso8601String();
      final updatedAt = DateTime.utc(2026, 1, 2).toIso8601String();

      final legacyDb = await openDatabase(
        databasePath,
        version: 21,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE ${AppDatabase.tripsTable} (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              destination TEXT NOT NULL,
              start_date TEXT,
              end_date TEXT,
              base_currency TEXT NOT NULL,
              destination_currency TEXT,
              home_currency_snapshot TEXT,
              budget REAL,
              budget_currency TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_custom_title INTEGER NOT NULL DEFAULT 0,
              destination_country_code TEXT
            )
          ''');
        },
      );

      await legacyDb.insert(AppDatabase.tripsTable, {
        'id': legacyTripId,
        'name': 'Legacy Trip',
        'destination': 'France',
        'base_currency': 'EUR',
        'destination_currency': 'EUR',
        'home_currency_snapshot': 'SAR',
        'created_at': createdAt,
        'updated_at': updatedAt,
        'is_custom_title': 0,
      });
      await legacyDb.close();

      final upgradedDb = await openDatabase(
        databasePath,
        version: AppDatabase.databaseVersion,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 22) {
            final columns = await db.rawQuery(
              'PRAGMA table_info(${AppDatabase.tripsTable})',
            );
            final hasDescription = columns.any(
              (column) => column['name'] == 'description',
            );
            if (!hasDescription) {
              await db.execute(
                'ALTER TABLE ${AppDatabase.tripsTable} ADD COLUMN description TEXT',
              );
            }
          }
        },
      );

      final rows = await upgradedDb.query(
        AppDatabase.tripsTable,
        where: 'id = ?',
        whereArgs: [legacyTripId],
      );

      expect(rows, hasLength(1));
      expect(rows.first['name'], 'Legacy Trip');
      expect(rows.first['description'], isNull);

      final migratedTrip = Trip.tryFromMap(rows.first);
      expect(migratedTrip?.description, isNull);

      final columns = (await upgradedDb.rawQuery(
        'PRAGMA table_info(${AppDatabase.tripsTable})',
      ))
          .map((row) => row['name'] as String)
          .toSet();
      expect(columns, contains('description'));

      await upgradedDb.close();
    });

    test('migration is idempotent', () async {
      const databaseFileName = 'trip_description_idempotent_test.db';
      final firstOpen = AppDatabase(databaseFileName: databaseFileName);
      await firstOpen.database;
      await firstOpen.close();

      final secondOpen = AppDatabase(databaseFileName: databaseFileName);
      final db = await secondOpen.database;
      final descriptionColumns = (await db.rawQuery(
        'PRAGMA table_info(${AppDatabase.tripsTable})',
      ))
          .where((row) => row['name'] == 'description')
          .toList();

      expect(descriptionColumns, hasLength(1));
      await secondOpen.close();
    });

    test('create trip with description', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-with-description',
          name: 'Paris Trip',
          destination: 'France',
          baseCurrency: 'EUR',
          description: 'Anniversary getaway',
        ),
      );

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, 'Anniversary getaway');
    });

    test('create trip without description', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-without-description',
          name: 'Tokyo Trip',
          destination: 'Japan',
          baseCurrency: 'JPY',
        ),
      );

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, isNull);
    });

    test('empty description stored as null', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-empty-description',
          name: 'Rome Trip',
          destination: 'Italy',
          baseCurrency: 'EUR',
          description: '',
        ),
      );

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, isNull);

      final db = await appDatabase.database;
      final row = await db.query(
        AppDatabase.tripsTable,
        where: 'id = ?',
        whereArgs: [created.id],
        limit: 1,
      );
      expect(row.first['description'], isNull);
    });

    test('whitespace description stored as null', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-whitespace-description',
          name: 'Berlin Trip',
          destination: 'Germany',
          baseCurrency: 'EUR',
          description: '   ',
        ),
      );

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, isNull);
    });

    test('load trip returns description', () async {
      await tripRepository.createTrip(
        Trip.create(
          id: 'trip-load-description',
          name: 'London Trip',
          destination: 'United Kingdom',
          baseCurrency: 'GBP',
          description: 'Business travel',
        ),
      );

      final trips = await tripRepository.getTrips();
      final trip = trips.firstWhere((entry) => entry.id == 'trip-load-description');

      expect(trip.description, 'Business travel');
    });

    test('update trip description', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-update-description',
          name: 'Madrid Trip',
          destination: 'Spain',
          baseCurrency: 'EUR',
        ),
      );

      final updated = await tripRepository.updateTrip(
        created.copyWith(description: 'Updated notes'),
      );

      expect(updated.description, 'Updated notes');

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, 'Updated notes');
    });

    test('clear trip description', () async {
      final created = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-clear-description',
          name: 'Lisbon Trip',
          destination: 'Portugal',
          baseCurrency: 'EUR',
          description: 'Summer holiday',
        ),
      );

      final updated = await tripRepository.updateTrip(
        created.copyWith(description: ''),
      );

      expect(updated.description, isNull);

      final loaded = await tripRepository.getTripById(created.id);
      expect(loaded?.description, isNull);
    });
  });
}
