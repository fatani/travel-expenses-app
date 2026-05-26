import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/async_notifier_reload.dart';
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
    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      state = AsyncData(await _loadTrips());
    } catch (error, stackTrace) {
      state = AsyncNotifierReload.errorPreserving(error, stackTrace, state);
    }
  }

  Future<Trip> createTrip({
    required String name,
    required String destination,
    DateTime? startDate,
    DateTime? endDate,
    required String baseCurrency,
    required String destinationCurrency,
    required String homeCurrencySnapshot,
    double? budget,
    String? budgetCurrency,
    bool isCustomTitle = false,
    String? destinationCountryCode,
  }) async {
    final trip = Trip.create(
      name: name,
      destination: destination,
      startDate: startDate != null ? _normalizeDate(startDate) : null,
      endDate: endDate != null ? _normalizeDate(endDate) : null,
      baseCurrency: baseCurrency,
      destinationCurrency: destinationCurrency,
      homeCurrencySnapshot: homeCurrencySnapshot,
      budget: budget,
      budgetCurrency: budgetCurrency,
      isCustomTitle: isCustomTitle,
      destinationCountryCode: destinationCountryCode,
    );

    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      final createdTrip = await ref.read(tripRepositoryProvider).createTrip(trip);
      ref.invalidate(globalReportProvider);
      state = AsyncData(await _loadTrips());
      return createdTrip;
    } catch (error, stackTrace) {
      state = AsyncNotifierReload.errorPreserving(error, stackTrace, state);
      rethrow;
    }
  }

  Future<void> updateTrip({
    required Trip trip,
    required String name,
    required String destination,
    DateTime? startDate,
    DateTime? endDate,
    required String baseCurrency,
    String? destinationCurrency,
    String? homeCurrencySnapshot,
    double? budget,
    String? budgetCurrency,
    bool? isCustomTitle,
    Object? destinationCountryCode = _unset,
  }) async {
    final updatedTrip = trip.copyWith(
      name: name,
      destination: destination,
      startDate: startDate != null ? _normalizeDate(startDate) : null,
      endDate: endDate != null ? _normalizeDate(endDate) : null,
      baseCurrency: baseCurrency,
      destinationCurrency: destinationCurrency,
      homeCurrencySnapshot: homeCurrencySnapshot,
      budget: budget,
      budgetCurrency: budgetCurrency,
      isCustomTitle: isCustomTitle,
      destinationCountryCode: identical(destinationCountryCode, _unset)
          ? trip.destinationCountryCode
          : destinationCountryCode as String?,
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
    state = AsyncNotifierReload.loadingPreserving(state);

    try {
      await mutation();
      ref.invalidate(globalReportProvider);
      state = AsyncData(await _loadTrips());
    } catch (error, stackTrace) {
      state = AsyncNotifierReload.errorPreserving(error, stackTrace, state);
      rethrow;
    }
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static const Object _unset = Object();
}
