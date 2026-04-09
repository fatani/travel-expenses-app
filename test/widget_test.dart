import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:travel_expenses/app/app.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  testWidgets('app initializes with trips list screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripRepositoryProvider.overrideWithValue(_FakeTripRepository()),
        ],
        child: const TravelExpensesApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.text('Add Trip'), findsWidgets);
  });
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository() : super(AppDatabase());

  @override
  Future<Trip> createTrip(Trip trip) async => trip;

  @override
  Future<void> deleteTrip(String id) async {}

  @override
  Future<Trip?> getTripById(String id) async => null;

  @override
  Future<List<Trip>> getTrips() async => const <Trip>[];

  @override
  Future<Trip> updateTrip(Trip trip) async => trip;
}
