import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_provider.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository() : super(AppDatabase());

  final List<Trip> _trips = [];
  int _idCounter = 0;

  @override
  Future<Trip> createTrip(Trip trip) async {
    _idCounter++;
    final created = trip.copyWith(
      id: trip.id.isEmpty ? 'trip-$_idCounter' : trip.id,
      updatedAt: DateTime.now().toUtc(),
    );
    _trips.add(created);
    return created;
  }

  @override
  Future<List<Trip>> getTrips() async => List<Trip>.from(_trips);

  @override
  Future<Trip?> getTripById(String id) async {
    for (final trip in _trips) {
      if (trip.id == id) {
        return trip;
      }
    }
    return null;
  }

  @override
  Future<Trip> updateTrip(Trip trip) async {
    final index = _trips.indexWhere((item) => item.id == trip.id);
    if (index >= 0) {
      _trips[index] = trip;
    }
    return trip;
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((trip) => trip.id == id);
  }
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository() : super(AppDatabase());

  final List<Expense> _expenses = [];
  int _idCounter = 0;

  @override
  Future<Expense> createExpense(Expense expense) async {
    _idCounter++;
    final created = expense.copyWith(
      id: expense.id.isEmpty ? 'expense-$_idCounter' : expense.id,
      updatedAt: DateTime.now().toUtc(),
    );
    _expenses.add(created);
    return created;
  }

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index >= 0) {
      _expenses[index] = expense;
    }
    return expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
  }
}

void main() {
  test('global report refreshes after trip deletion', () async {
    final tripRepository = _FakeTripRepository();
    final expenseRepository = _FakeExpenseRepository();
    final container = ProviderContainer(
      overrides: [
        tripRepositoryProvider.overrideWithValue(tripRepository),
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
      ],
    );
    addTearDown(container.dispose);

    final tripsController = container.read(tripsControllerProvider.notifier);

    await tripsController.createTrip(
      name: 'Trip 1',
      destination: 'Riyadh',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2026, 4, 2),
      baseCurrency: 'SAR',
    );
    await tripsController.createTrip(
      name: 'Trip 2',
      destination: 'Jeddah',
      startDate: DateTime(2026, 4, 3),
      endDate: DateTime(2026, 4, 4),
      baseCurrency: 'SAR',
    );

    final tripsBeforeDelete = await container.read(tripsControllerProvider.future);
    final firstTrip = tripsBeforeDelete.first;

    await expenseRepository.createExpense(
      Expense.create(
        tripId: firstTrip.id,
        title: 'Hotel',
        amount: 250,
        currencyCode: 'SAR',
        paymentMethod: 'Card',
        category: 'Accommodation',
      ),
    );

    final summaryBeforeDelete = await container.read(globalReportProvider.future);
    expect(summaryBeforeDelete.totalTrips, 2);
    expect(summaryBeforeDelete.activeTrips, 1);

    await tripsController.deleteTrip(firstTrip.id);

    final summaryAfterDelete = await container.read(globalReportProvider.future);
    expect(summaryAfterDelete.totalTrips, 1);
    expect(summaryAfterDelete.activeTrips, 0);
    expect(summaryAfterDelete.totalExpenseCount, 0);
  });
}
