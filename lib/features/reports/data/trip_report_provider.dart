import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/remaining_cash_value.dart';
import '../domain/trip_report_display.dart';
import 'trip_report_calculator.dart';

final tripReportProvider =
    FutureProvider.autoDispose.family<TripReportDisplay, String>((
      ref,
      tripId,
    ) async {
      final expenseRepo = ref.watch(expenseRepositoryProvider);
      final tripRepo = ref.watch(tripRepositoryProvider);
      final lotRepo = ref.watch(cashLotRepositoryProvider);

      final trip = await tripRepo.getTripById(tripId);
      final expenses = await expenseRepo.getExpensesByTrip(tripId);

      // Fetch lot-based remaining cash summaries (FIFO cost basis).
      final homeCurrency = trip?.homeCurrencySnapshot;
      final List<RemainingCashValue> lotRemainingValues;
      if (homeCurrency != null) {
        final summaries = await lotRepo.computeLotCurrencySummaries(
          tripId: tripId,
          homeCurrencyCode: homeCurrency,
        );
        lotRemainingValues = summaries
            .where((s) => s.totalRemainingAmount > 0)
            .map((s) => RemainingCashValue(
                  currencyCode: s.currencyCode,
                  balanceAmount: s.totalRemainingAmount,
                  effectiveRate: s.totalHomeAmount / s.totalRemainingAmount,
                  homeAmount: s.totalHomeAmount,
                  homeCurrency: s.homeCurrencyCode,
                ))
            .toList();
      } else {
        lotRemainingValues = const [];
      }

      // Fetch all active (non-reversed) lots for Cash Acquisition Summary.
      final activeLots = await lotRepo.getActiveLotsForTrip(tripId);

      final refundRepo = ref.read(expenseRefundRepositoryProvider);
      final refunds = await refundRepo.getActiveRefundsByTrip(tripId);

      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: tripId,
        tripName: trip?.name ?? tripId,
        expenses: expenses,
        tripHomeCurrency: homeCurrency,
        refunds: refunds,
        lotRemainingValues: lotRemainingValues,
        activeLots: activeLots,
      );

      return TripReportDisplay(
        summary: summary,
        refundsByTransactionCurrency:
            buildRefundsByTransactionCurrency(refunds),
      );
    });
