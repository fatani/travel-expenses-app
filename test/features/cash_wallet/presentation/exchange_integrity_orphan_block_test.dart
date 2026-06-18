import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Test 1 — Exchange Office + blank home value must NOT create anything.
///
/// Proves the orphan-inflow path is unreachable from the UI: the save is
/// blocked with a validation message, neither addCashTransaction nor the
/// exchange use case is invoked, and no balance changes.
void main() {
  final trip = Trip.create(
    id: 'trip-exchange-orphan-block',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  testWidgets('blocks Exchange Office save when home value is blank',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final walletRepo = _SpyCashWalletRepository();
    final exchangeUseCase = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(walletRepo),
          recordCurrencyExchangeUseCaseProvider
              .overrideWithValue(exchangeUseCase),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripCashWalletScreen(trip: trip),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();

    // Select "Exchange office" as the cash source.
    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exchange office').last);
    await tester.pumpAndSettle();

    // Enter the received amount; leave the home value blank.
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '720');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Validation blocks the save.
    expect(
      find.text('Enter the home value you exchanged to record this exchange.'),
      findsOneWidget,
    );
    // Nothing was recorded through either path.
    expect(walletRepo.addCallCount, 0);
    expect(exchangeUseCase.executeCallCount, 0);
  });
}

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository() : super(AppDatabase());

  int addCallCount = 0;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      const [];

  @override
  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    addCallCount += 1;
  }
}

class _SpyExchangeUseCase extends RecordCurrencyExchangeUseCase {
  _SpyExchangeUseCase(AppDatabase db)
      : super(
          appDatabase: db,
          exchangeEngine:
              CurrencyExchangeEngine(CashLotFifoEngine(CashLotRepository(db))),
          cashWalletRepository: CashWalletRepository(db),
          lotRepository: CashLotRepository(db),
          consumptionRepository: CashLotConsumptionRepository(db),
          exchangeRepository: CurrencyExchangeRepository(db),
        );

  int executeCallCount = 0;

  @override
  Future<CurrencyExchangeResult> execute({
    required String tripId,
    required String fromCurrencyCode,
    required double fromAmount,
    required String toCurrencyCode,
    required double toAmount,
    String? note,
    DateTime? createdAt,
  }) async {
    executeCallCount += 1;
    throw StateError('exchange use case must not be called when blocked');
  }
}
