import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/manual_currency_conversion_service.dart';
import '../finance/manual_exchange_rate_repository.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/cash_wallet/data/cash_wallet_repository.dart';
import '../../features/financial_profile/data/user_financial_profile_repository.dart';
import '../../features/settings/data/card_repository.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/trips/data/trip_repository.dart';
import '../database/app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final appDatabase = AppDatabase();
  ref.onDispose(appDatabase.close);
  return appDatabase;
});

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(appDatabaseProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(appDatabaseProvider));
});

final cashWalletRepositoryProvider = Provider<CashWalletRepository>((ref) {
  return CashWalletRepository(ref.watch(appDatabaseProvider));
});

final manualExchangeRateRepositoryProvider =
    Provider<ManualExchangeRateRepository>((ref) {
      return ManualExchangeRateRepository(ref.watch(appDatabaseProvider));
    });

final manualCurrencyConversionServiceProvider =
    Provider<ManualCurrencyConversionService>((ref) {
      return ManualCurrencyConversionService(
        ref.watch(manualExchangeRateRepositoryProvider),
      );
    });

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(appDatabaseProvider));
});

final userFinancialProfileRepositoryProvider =
    Provider<UserFinancialProfileRepository>((ref) {
      return UserFinancialProfileRepository(ref.watch(appDatabaseProvider));
    });
