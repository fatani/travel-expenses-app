import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import 'global_report_calculator.dart';
import '../domain/global_report_summary.dart';

final globalReportProvider = FutureProvider.autoDispose<GlobalReportSummary>((
  ref,
) async {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final expenseRepository = ref.watch(expenseRepositoryProvider);

  final trips = await tripRepository.getTrips();
  final expenseLists = await Future.wait(
    trips.map((trip) => expenseRepository.getExpensesByTrip(trip.id)),
  );
  final expenses = expenseLists.expand((items) => items).toList(growable: false);

  const calculator = GlobalReportCalculator();
  return calculator.calculate(trips: trips, expenses: expenses);
});
