import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../trips/domain/trip.dart';
import '../domain/trip_prediction_summary.dart';
import 'trip_prediction_calculator.dart';

final tripPredictionProvider =
    FutureProvider.autoDispose.family<TripPredictionSummary?, Trip>((
      ref,
      trip,
    ) async {
      final repo = ref.watch(expenseRepositoryProvider);
      final expenses = await repo.getExpensesByTrip(trip.id);
      const calculator = TripPredictionCalculator();
      return calculator.calculate(trip: trip, expenses: expenses);
    });
