import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/backup/presentation/backup_restore_provider_refresh.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/financial_profile/presentation/user_financial_profile_controller.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_provider.dart';
import 'package:travel_expenses/features/predictions/data/trip_prediction_provider.dart';
import 'package:travel_expenses/features/reports/data/trip_cash_balances_provider.dart';
import 'package:travel_expenses/features/reports/data/trip_report_provider.dart';
import 'package:travel_expenses/features/settings/presentation/cards_provider.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';

void main() {
  test('restoreInvalidationProviders lists all DB-backed providers', () {
    expect(restoreInvalidationProviders, contains(tripsControllerProvider));
    expect(restoreInvalidationProviders, contains(settingsControllerProvider));
    expect(restoreInvalidationProviders, contains(cardsProvider));
    expect(
      restoreInvalidationProviders,
      contains(userFinancialProfileControllerProvider),
    );
    expect(restoreInvalidationProviders, contains(globalReportProvider));
    expect(restoreInvalidationProviders, contains(tripReportProvider));
    expect(restoreInvalidationProviders, contains(tripPredictionProvider));
    expect(restoreInvalidationProviders, contains(tripCashBalancesProvider));
    expect(restoreInvalidationProviders, contains(expenseControllerProvider));
  });

  test('refreshProvidersAfterRestoreContainer invalidates core notifiers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(tripsControllerProvider);
    container.read(settingsControllerProvider);
    container.read(cardsProvider);

    expect(
      () => refreshProvidersAfterRestoreContainer(container),
      returnsNormally,
    );

    expect(container.read(tripsControllerProvider), isA<AsyncLoading>());
    expect(container.read(settingsControllerProvider), isA<AsyncLoading>());
    expect(container.read(cardsProvider), isA<AsyncLoading>());
  });
}
