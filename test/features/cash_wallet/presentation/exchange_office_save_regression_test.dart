import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Regression — dedicated Exchange Money sheet save/validation feedback.
void main() {
  final trip = Trip.create(
    id: 'trip-exchange-office-regression',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  Widget buildApp({
    required CashWalletRepository repository,
    required RecordCurrencyExchangeUseCase exchangeUseCase,
  }) {
    return ProviderScope(
      overrides: [
        cashWalletRepositoryProvider.overrideWithValue(repository),
        recordCurrencyExchangeUseCaseProvider.overrideWithValue(exchangeUseCase),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripCashWalletScreen(trip: trip),
      ),
    );
  }

  void sizeLarge(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  TripCashBalance balance(String code, double amount) => TripCashBalance(
        tripId: trip.id,
        currencyCode: code,
        balanceAmount: amount,
        updatedAt: DateTime.now().toUtc(),
      );

  Future<void> openExchangeSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Exchange Money'));
    await tester.pumpAndSettle();
  }

  testWidgets('valid exchange routes to the engine and closes the sheet',
      (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository(
      balances: [balance('USD', 500)],
      transactions: [
        CashTransaction.create(
          id: 'usd',
          tripId: trip.id,
          type: CashTransactionType.initialCash,
          amount: 500,
          currencyCode: 'USD',
        ),
      ],
    );
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '100');
    await tester.enterText(fields.at(1), '720');

    await tester.ensureVisible(find.text('Save exchange'));
    await tester.tap(find.text('Save exchange'));
    await tester.pumpAndSettle();

    expect(exchange.executeCallCount, 1);
    expect(exchange.lastFromCurrency, 'USD');
    expect(exchange.lastFromAmount, 100);
    expect(exchange.lastToCurrency, 'CNY');
    expect(exchange.lastToAmount, 720);
    expect(find.text('Save exchange'), findsNothing);
  });

  testWidgets('blank gave amount shows inline validation', (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository(
      balances: [balance('USD', 500)],
      transactions: [
        CashTransaction.create(
          id: 'usd',
          tripId: trip.id,
          type: CashTransactionType.initialCash,
          amount: 500,
          currencyCode: 'USD',
        ),
      ],
    );
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    await tester.enterText(find.byType(TextField).at(1), '720');

    await tester.ensureVisible(find.text('Save exchange'));
    await tester.tap(find.text('Save exchange'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the amount you gave.'), findsOneWidget);
    expect(exchange.executeCallCount, 0);
    expect(find.text('Save exchange'), findsOneWidget);
  });

  testWidgets('insufficient source cash shows inline error', (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository(
      balances: [balance('USD', 500)],
      transactions: [
        CashTransaction.create(
          id: 'usd',
          tripId: trip.id,
          type: CashTransactionType.initialCash,
          amount: 500,
          currencyCode: 'USD',
        ),
      ],
    );
    final exchange = _SpyExchangeUseCase(AppDatabase())
      ..errorToThrow = const InsufficientCashException(
        required: 600,
        available: 500,
        currencyCode: 'USD',
      );

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '600');
    await tester.enterText(fields.at(1), '4320');

    await tester.ensureVisible(find.text('Save exchange'));
    await tester.tap(find.text('Save exchange'));
    await tester.pumpAndSettle();

    expect(exchange.executeCallCount, 0);
    expect(find.text('Not enough USD cash in this trip.'), findsOneWidget);
    expect(find.text('Save exchange'), findsOneWidget);
  });

  testWidgets('Received or Found Cash still saves', (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository();
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Received or Found Cash').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '250');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repo.addCallCount, 1);
    expect(repo.lastType, CashTransactionType.manualAdjustment);
    expect(exchange.executeCallCount, 0);
  });
}

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository({
    this.balances = const [],
    this.transactions = const [],
  }) : super(AppDatabase());

  final List<TripCashBalance> balances;
  final List<CashTransaction> transactions;

  int addCallCount = 0;
  CashTransactionType? lastType;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      balances;

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      transactions;

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
    lastType = type;
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
  String? lastFromCurrency;
  double? lastFromAmount;
  String? lastToCurrency;
  double? lastToAmount;
  Object? errorToThrow;

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
    lastFromCurrency = fromCurrencyCode;
    lastFromAmount = fromAmount;
    lastToCurrency = toCurrencyCode;
    lastToAmount = toAmount;

    final err = errorToThrow;
    if (err != null) {
      throw err;
    }

    final lot = CashLot.create(
      id: 'dest-lot',
      tripId: tripId,
      sourceType: 'exchange_in',
      sourceRefType: 'currency_exchange',
      sourceRefId: 'exch',
      currencyCode: toCurrencyCode,
      originalAmount: toAmount,
    );
    return CurrencyExchangeResult(
      exchange: CurrencyExchange.create(
        id: 'exch',
        tripId: tripId,
        fromCurrencyCode: fromCurrencyCode,
        fromAmount: fromAmount,
        toCurrencyCode: toCurrencyCode,
        toAmount: toAmount,
        exchangeRate: toAmount / fromAmount,
        toLotId: lot.id,
      ),
      destinationLot: lot,
      exchangeOutTransaction: CashTransaction.create(
        id: 'out',
        tripId: tripId,
        type: CashTransactionType.currencyExchangeOut,
        amount: fromAmount,
        currencyCode: fromCurrencyCode,
      ),
      exchangeInTransaction: CashTransaction.create(
        id: 'in',
        tripId: tripId,
        type: CashTransactionType.currencyExchangeIn,
        amount: toAmount,
        currencyCode: toCurrencyCode,
        lotId: lot.id,
      ),
      consumptions: const [],
    );
  }
}
