import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/trip_prediction_summary.dart';
import 'trip_prediction_calculator.dart';

final tripPredictionProvider =
    FutureProvider.autoDispose.family<TripPredictionSummary?, String>((
      ref,
      tripId,
    ) async {
      final expenseRepo = ref.watch(expenseRepositoryProvider);
      final tripRepo = ref.watch(tripRepositoryProvider);
      final trip = await tripRepo.getTripById(tripId);
      if (trip == null) {
        return null;
      }

      final expenses = await expenseRepo.getExpensesByTrip(tripId);
      const calculator = TripPredictionCalculator();
      return calculator.calculate(trip: trip, expenses: expenses);
    });
