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

/// Critical Regression — "Exchange Office save does nothing".
///
/// A modal bottom sheet covers the floating snackbar area, so save/validation
/// failures previously produced no visible feedback. These tests verify that a
/// valid exchange routes to the engine, and every failure is surfaced inline.
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

  Future<void> openExchangeSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exchange office').last);
    await tester.pumpAndSettle();
  }

  // ── Test 1 — valid exchange routes to the engine and closes the sheet ──────
  testWidgets('Exchange Office + valid value saves through the exchange engine',
      (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository();
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2000'); // received CNY
    await tester.enterText(fields.at(1), '1120'); // SAR exchanged

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(exchange.executeCallCount, 1);
    expect(exchange.lastFromCurrency, 'SAR'); // home currency given
    expect(exchange.lastFromAmount, 1120);
    expect(exchange.lastToCurrency, 'CNY');
    expect(exchange.lastToAmount, 2000);
    // Sheet closed, no error.
    expect(find.text('Amount you exchanged'), findsNothing);
  });

  // ── Test 2 — blank source value shows inline validation, no engine call ────
  testWidgets('Exchange Office + blank value shows inline validation',
      (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository();
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    await tester.enterText(find.byType(TextField).at(0), '2000');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter the home value you exchanged to record this exchange.'),
      findsOneWidget,
    );
    expect(exchange.executeCallCount, 0);
    expect(find.text('Amount you exchanged'), findsWidgets); // sheet still open
  });

  // ── Test 3 — insufficient source cash shows a visible, named error ─────────
  testWidgets('Exchange Office + insufficient source cash shows inline error',
      (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository();
    final exchange = _SpyExchangeUseCase(AppDatabase())
      ..errorToThrow = const InsufficientCashException(
        required: 1120,
        available: 500,
        currencyCode: 'SAR',
      );

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '2000');
    await tester.enterText(fields.at(1), '1120');

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(exchange.executeCallCount, 1);
    expect(
      find.text('Not enough SAR cash recorded to make this exchange.'),
      findsOneWidget,
    );
    expect(find.text('Amount you exchanged'), findsWidgets); // sheet still open
  });

  // ── Test 4 — Received or Found Cash still saves ────────────────────────────
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

  // ── Test 5 — Exchange label is required, not "optional" ────────────────────
  testWidgets('Exchange Office source field is required, not optional',
      (tester) async {
    sizeLarge(tester);
    final repo = _SpyCashWalletRepository();
    final exchange = _SpyExchangeUseCase(AppDatabase());

    await tester.pumpWidget(
      buildApp(repository: repo, exchangeUseCase: exchange),
    );
    await tester.pumpAndSettle();
    await openExchangeSheet(tester);

    expect(find.text('Amount you exchanged'), findsWidgets);
    expect(find.text('Required to record an exchange correctly.'), findsWidgets);
    expect(find.text('Approximate home value (optional)'), findsNothing);
  });
}

class _SpyCashWalletRepository extends CashWalletRepository {
  _SpyCashWalletRepository() : super(AppDatabase());

  int addCallCount = 0;
  CashTransactionType? lastType;

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
