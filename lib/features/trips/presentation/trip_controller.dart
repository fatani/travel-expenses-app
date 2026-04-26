import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../domain/trip.dart';

final tripsControllerProvider =
    AsyncNotifierProvider<TripsController, List<Trip>>(TripsController.new);

class TripsController extends AsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() {
    return _loadTrips();
  }

  Future<void> reload() async {
    state = const AsyncLoading();

    try {
      state = AsyncData(await _loadTrips());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> createTrip({
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String baseCurrency,
    double? budget,
    String? budgetCurrency,
  }) async {
    final trip = Trip.create(
      name: name,
      destination: destination,
      startDate: _normalizeDate(startDate),
      endDate: _normalizeDate(endDate),
      baseCurrency: baseCurrency,
      budget: budget,
      budgetCurrency: budgetCurrency,
    );

    await _runMutation(() => ref.read(tripRepositoryProvider).createTrip(trip));
  }

  Future<void> updateTrip({
    required Trip trip,
    required String name,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required String baseCurrency,
    double? budget,
    String? budgetCurrency,
  }) async {
    final updatedTrip = trip.copyWith(
      name: name,
      destination: destination,
      startDate: _normalizeDate(startDate),
      endDate: _normalizeDate(endDate),
      baseCurrency: baseCurrency,
      budget: budget,
      budgetCurrency: budgetCurrency,
    );

    await _runMutation(
      () => ref.read(tripRepositoryProvider).updateTrip(updatedTrip),
    );
  }

  Future<void> deleteTrip(String id) async {
    await _runMutation(() => ref.read(tripRepositoryProvider).deleteTrip(id));
  }

  Future<List<Trip>> _loadTrips() async {
    return ref.read(tripRepositoryProvider).getTrips();
  }

  Future<void> _runMutation(Future<void> Function() mutation) async {
    state = const AsyncLoading();

    try {
      await mutation();
      ref.invalidate(globalReportProvider);
      state = AsyncData(await _loadTrips());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
