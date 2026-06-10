import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../finance/manual_currency_conversion_service.dart';
import '../finance/manual_exchange_rate_repository.dart';
import '../../features/cash_wallet/data/cash_lot_consumption_repository.dart';
import '../../features/cash_wallet/data/cash_lot_repository.dart';
import '../../features/cash_wallet/data/cash_wallet_repository.dart';
import '../../features/cash_wallet/data/currency_exchange_repository.dart';
import '../../features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import '../../features/cash_wallet/domain/currency_exchange_engine.dart';
import '../../features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import '../../features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../features/expenses/domain/record_cash_expense_use_case.dart';
import '../../features/financial_profile/data/user_financial_profile_repository.dart';
import '../../features/refunds/data/expense_refund_repository.dart';
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

final expenseRefundRepositoryProvider = Provider<ExpenseRefundRepository>((ref) {
  return ExpenseRefundRepository(ref.watch(appDatabaseProvider));
});

final cashLotRepositoryProvider = Provider<CashLotRepository>((ref) {
  return CashLotRepository(ref.watch(appDatabaseProvider));
});

final cashLotConsumptionRepositoryProvider =
    Provider<CashLotConsumptionRepository>((ref) {
  return CashLotConsumptionRepository(ref.watch(appDatabaseProvider));
});

final currencyExchangeRepositoryProvider =
    Provider<CurrencyExchangeRepository>((ref) {
  return CurrencyExchangeRepository(ref.watch(appDatabaseProvider));
});

final cashLotFifoEngineProvider = Provider<CashLotFifoEngine>((ref) {
  return CashLotFifoEngine(ref.watch(cashLotRepositoryProvider));
});

final currencyExchangeEngineProvider = Provider<CurrencyExchangeEngine>((ref) {
  return CurrencyExchangeEngine(ref.watch(cashLotFifoEngineProvider));
});

final recordAtmWithdrawalUseCaseProvider =
    Provider<RecordAtmWithdrawalUseCase>((ref) {
  return RecordAtmWithdrawalUseCase(
    appDatabase: ref.watch(appDatabaseProvider),
    cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
    lotRepository: ref.watch(cashLotRepositoryProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
  );
});

final recordCurrencyExchangeUseCaseProvider =
    Provider<RecordCurrencyExchangeUseCase>((ref) {
  return RecordCurrencyExchangeUseCase(
    appDatabase: ref.watch(appDatabaseProvider),
    exchangeEngine: ref.watch(currencyExchangeEngineProvider),
    cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
    lotRepository: ref.watch(cashLotRepositoryProvider),
    consumptionRepository: ref.watch(cashLotConsumptionRepositoryProvider),
    exchangeRepository: ref.watch(currencyExchangeRepositoryProvider),
  );
});

final recordCashExpenseUseCaseProvider =
    Provider<RecordCashExpenseUseCase>((ref) {
  return RecordCashExpenseUseCase(
    appDatabase: ref.watch(appDatabaseProvider),
    expenseRepository: ref.watch(expenseRepositoryProvider),
    cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
    fifoEngine: ref.watch(cashLotFifoEngineProvider),
    lotRepository: ref.watch(cashLotRepositoryProvider),
    consumptionRepository: ref.watch(cashLotConsumptionRepositoryProvider),
  );
});
