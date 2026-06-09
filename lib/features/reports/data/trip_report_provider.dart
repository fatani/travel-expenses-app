import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/remaining_cash_value.dart';
import '../domain/trip_report_summary.dart';
import 'trip_report_calculator.dart';

final tripReportProvider =
    FutureProvider.autoDispose.family<TripReportSummary, String>((
      ref,
      tripId,
    ) async {
      final expenseRepo = ref.watch(expenseRepositoryProvider);
      final cashWalletRepo = ref.watch(cashWalletRepositoryProvider);
      final tripRepo = ref.watch(tripRepositoryProvider);

      final trip = await tripRepo.getTripById(tripId);
      final expenses = await expenseRepo.getExpensesByTrip(tripId);

      // Fetch balances and compute effective rates for Remaining Cash Cost Basis.
      final homeCurrency = trip?.homeCurrencySnapshot;
      final balances = await cashWalletRepo.getBalancesByTrip(tripId);
      final cashBalanceRates = await Future.wait(
        balances.map((balance) async {
          final rate = homeCurrency != null
              ? await cashWalletRepo.getEffectiveCashRate(
                  tripId: tripId,
                  transactionCurrencyCode: balance.currencyCode,
                  homeCurrencyCode: homeCurrency,
                )
              : null;
          return CashBalanceRateInput(
            balance: balance,
            effectiveRate: rate,
            homeCurrency: homeCurrency,
          );
        }),
      );

      final refundRepo = ref.read(expenseRefundRepositoryProvider);
      final refunds = await refundRepo.getActiveRefundsByTrip(tripId);

      const calculator = TripReportCalculator();
      return calculator.calculate(
        tripId: tripId,
        tripName: trip?.name ?? tripId,
        expenses: expenses,
        refunds: refunds,
        cashBalanceRates: cashBalanceRates,
      );
    });
