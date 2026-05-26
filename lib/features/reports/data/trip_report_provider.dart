import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/trip_report_summary.dart';
import 'trip_report_calculator.dart';

final tripReportProvider =
    FutureProvider.autoDispose.family<TripReportSummary, String>((
      ref,
      tripId,
    ) async {
      final expenseRepo = ref.watch(expenseRepositoryProvider);
      final tripRepo = ref.watch(tripRepositoryProvider);
      final trip = await tripRepo.getTripById(tripId);
      final expenses = await expenseRepo.getExpensesByTrip(tripId);
      const calculator = TripReportCalculator();
      return calculator.calculate(
        tripId: tripId,
        tripName: trip?.name ?? tripId,
        expenses: expenses,
      );
    });
