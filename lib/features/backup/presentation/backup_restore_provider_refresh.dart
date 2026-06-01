import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../expenses/presentation/expense_controller.dart';
import '../../financial_profile/presentation/user_financial_profile_controller.dart';
import '../../global_reports/data/global_report_provider.dart';
import '../../predictions/data/trip_prediction_provider.dart';
import '../../reports/data/trip_cash_balances_provider.dart';
import '../../reports/data/trip_report_provider.dart';
import '../../settings/presentation/cards_provider.dart';
import '../../settings/presentation/settings_controller.dart';
import '../../trips/presentation/trip_controller.dart';

/// Providers invalidated after a successful full-replace restore.
final restoreInvalidationProviders = <ProviderOrFamily>[
  tripsControllerProvider,
  settingsControllerProvider,
  cardsProvider,
  userFinancialProfileControllerProvider,
  globalReportProvider,
  tripReportProvider,
  tripPredictionProvider,
  tripCashBalancesProvider,
  expenseControllerProvider,
];

/// Reloads all DB-backed Riverpod state after a successful full-replace restore.
void refreshProvidersAfterRestore(WidgetRef ref) {
  for (final provider in restoreInvalidationProviders) {
    ref.invalidate(provider);
  }
}

/// Testable variant for [ProviderContainer].
void refreshProvidersAfterRestoreContainer(ProviderContainer container) {
  for (final provider in restoreInvalidationProviders) {
    container.invalidate(provider);
  }
}
