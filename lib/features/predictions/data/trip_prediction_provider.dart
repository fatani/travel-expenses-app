import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

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
      final summary = calculator.calculate(trip: trip, expenses: expenses);

      final endDate = trip.endDate;
      final today = DateTime.now();
      final isTripEnded =
          endDate != null && !DateTime(today.year, today.month, today.day).isBefore(
            DateTime(endDate.year, endDate.month, endDate.day),
          );

      debugPrint(
        '[TripPredictionProvider] trip=${trip.id} '
        'expenses=${expenses.length} '
        'tripEnded=${summary?.isTripEnded ?? isTripEnded} '
        'summaryNull=${summary == null} '
        'elapsed=${summary?.elapsedDays ?? -1} '
        'remaining=${summary?.remainingDays ?? -1} '
        'burnRates=${summary?.burnRateByCurrency.length ?? 0} '
        'forecasts=${summary?.forecastTotalByCurrency.length ?? 0} '
        'actions=${summary?.actions.length ?? 0}',
      );

      return summary;
    });
