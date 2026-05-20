import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../domain/trip_report_summary.dart';
import 'trip_report_calculator.dart';

final tripReportProvider =
    FutureProvider.autoDispose.family<TripReportSummary, Trip>((
      ref,
      trip,
    ) async {
      final repo = ref.watch(expenseRepositoryProvider);
      final expenses = await repo.getExpensesByTrip(trip.id);
      const calculator = TripReportCalculator();
      return calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
      );
    });
