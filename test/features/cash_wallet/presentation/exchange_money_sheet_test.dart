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

TripCashBalance _balance(String tripId, String code, double amount) {
  return TripCashBalance(
    tripId: tripId,
    currencyCode: code,
    balanceAmount: amount,
    updatedAt: DateTime.now().toUtc(),
  );
}

void main() {
  final chinaTrip = Trip.create(
    id: 'trip-exchange-china',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  final thailandTrip = Trip.create(
    id: 'trip-exchange-thailand',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  void sizeLarge(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<void> openExchangeSheet(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Exchange Money'));
    await tester.pumpAndSettle();
  }

  Widget buildApp({
    required Trip trip,
    required CashWalletRepository repository,
    RecordCurrencyExchangeUseCase? exchangeUseCase,
  }) {
    return ProviderScope(
      overrides: [
        cashWalletRepositoryProvider.overrideWithValue(repository),
        if (exchangeUseCase != null)
          recordCurrencyExchangeUseCaseProvider.overrideWithValue(exchangeUseCase),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripCashWalletScreen(trip: trip),
      ),
    );
  }

  group('Exchange Money sheet — creation', () {
    testWidgets('100 USD → 720 CNY when USD cash exists', (tester) async {
      sizeLarge(tester);
      final exchange = _SpyExchangeUseCase(AppDatabase());
      final repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'USD', 200),
        _balance(chinaTrip.id, 'CNY', 0),
      ], transactions: [
        CashTransaction.create(
          id: 'usd-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 200,
          currencyCode: 'USD',
        ),
      ]);

      await tester.pumpWidget(
        buildApp(trip: chinaTrip, repository: repo, exchangeUseCase: exchange),
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

    testWidgets('50 EUR → 410 CNY when EUR cash exists', (tester) async {
      sizeLarge(tester);
      final exchange = _SpyExchangeUseCase(AppDatabase());
      final repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'EUR', 100),
      ], transactions: [
        CashTransaction.create(
          id: 'eur-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 100,
          currencyCode: 'EUR',
        ),
      ]);

      await tester.pumpWidget(
        buildApp(trip: chinaTrip, repository: repo, exchangeUseCase: exchange),
      );
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('EUR').last);
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '50');
      await tester.enterText(fields.at(1), '410');

      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(exchange.executeCallCount, 1);
      expect(exchange.lastFromCurrency, 'EUR');
      expect(exchange.lastFromAmount, 50);
      expect(exchange.lastToCurrency, 'CNY');
      expect(exchange.lastToAmount, 410);
    });

    testWidgets('500 SAR → 9600 THB when SAR cash exists', (tester) async {
      sizeLarge(tester);
      final exchange = _SpyExchangeUseCase(AppDatabase());
      final repo = _BalancesCashWalletRepository([
        _balance(thailandTrip.id, 'SAR', 1000),
      ], transactions: [
        CashTransaction.create(
          id: 'sar-init',
          tripId: thailandTrip.id,
          type: CashTransactionType.initialCash,
          amount: 1000,
          currencyCode: 'SAR',
        ),
      ]);

      await tester.pumpWidget(
        buildApp(
          trip: thailandTrip,
          repository: repo,
          exchangeUseCase: exchange,
        ),
      );
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '500');
      await tester.enterText(fields.at(1), '9600');

      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(exchange.executeCallCount, 1);
      expect(exchange.lastFromCurrency, 'SAR');
      expect(exchange.lastFromAmount, 500);
      expect(exchange.lastToCurrency, 'THB');
      expect(exchange.lastToAmount, 9600);
    });
  });

  group('Exchange Money sheet — validation', () {
    late _BalancesCashWalletRepository repo;
    late _SpyExchangeUseCase exchange;

    setUp(() {
      repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'USD', 100),
      ], transactions: [
        CashTransaction.create(
          id: 'usd-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 100,
          currencyCode: 'USD',
        ),
      ]);
      exchange = _SpyExchangeUseCase(AppDatabase());
    });

    Future<void> pumpAndOpen(WidgetTester tester) async {
      await tester.pumpWidget(
        buildApp(trip: chinaTrip, repository: repo, exchangeUseCase: exchange),
      );
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);
    }

    testWidgets('blocks missing gave amount', (tester) async {
      sizeLarge(tester);
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the amount you gave.'), findsOneWidget);
      expect(exchange.executeCallCount, 0);
      expect(find.text('Save exchange'), findsOneWidget);
    });

    testWidgets('blocks missing received amount', (tester) async {
      sizeLarge(tester);
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the amount you received.'), findsOneWidget);
      expect(exchange.executeCallCount, 0);
    });

    testWidgets('blocks zero amount', (tester) async {
      sizeLarge(tester);
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
      expect(exchange.executeCallCount, 0);
    });

    testWidgets('blocks negative amount', (tester) async {
      sizeLarge(tester);
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(0), '-10');
      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(find.text('Amount must be greater than zero.'), findsOneWidget);
      expect(exchange.executeCallCount, 0);
    });

    testWidgets('blocks same source and destination currency', (tester) async {
      sizeLarge(tester);
      repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'CNY', 500),
      ], transactions: [
        CashTransaction.create(
          id: 'cny-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 500,
          currencyCode: 'CNY',
        ),
      ]);

      await pumpAndOpen(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('CNY').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(
        find.text("You can't exchange a currency for itself."),
        findsOneWidget,
      );
      expect(exchange.executeCallCount, 0);
    });

    testWidgets('blocks insufficient source balance with inline message',
        (tester) async {
      sizeLarge(tester);
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(0), '150');
      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(
        find.text('Not enough USD cash in this trip.'),
        findsOneWidget,
      );
      expect(exchange.executeCallCount, 0);
      expect(find.text('Save exchange'), findsOneWidget);
    });

    testWidgets('maps engine insufficient cash to inline message',
        (tester) async {
      sizeLarge(tester);
      exchange.errorToThrow = const InsufficientCashException(
        required: 100,
        available: 50,
        currencyCode: 'USD',
      );
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.tap(find.text('Save exchange'));
      await tester.pumpAndSettle();

      expect(
        find.text('Not enough USD cash in this trip.'),
        findsOneWidget,
      );
      expect(find.text('Save exchange'), findsOneWidget);
    });
  });

  group('Exchange Money sheet — UX behavior', () {
    testWidgets('source picker shows held currencies with balances',
        (tester) async {
      sizeLarge(tester);
      final repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'USD', 100),
        _balance(chinaTrip.id, 'EUR', 50),
      ], transactions: [
        CashTransaction.create(
          id: 'usd-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 100,
          currencyCode: 'USD',
        ),
      ]);

      await tester.pumpWidget(
        buildApp(trip: chinaTrip, repository: repo),
      );
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();

      expect(find.textContaining('USD'), findsWidgets);
      expect(find.textContaining('EUR'), findsWidgets);
      expect(find.textContaining('100'), findsWidgets);
    });

    testWidgets('destination currency is locked to trip destination',
        (tester) async {
      sizeLarge(tester);
      final repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'USD', 100),
      ], transactions: [
        CashTransaction.create(
          id: 'usd-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 100,
          currencyCode: 'USD',
        ),
      ]);

      await tester.pumpWidget(buildApp(trip: chinaTrip, repository: repo));
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      expect(find.text('Destination currency'), findsOneWidget);
      expect(find.textContaining('CNY'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('rate preview appears only when both amounts are valid',
        (tester) async {
      sizeLarge(tester);
      final repo = _BalancesCashWalletRepository([
        _balance(chinaTrip.id, 'USD', 100),
      ], transactions: [
        CashTransaction.create(
          id: 'usd-init',
          tripId: chinaTrip.id,
          type: CashTransactionType.initialCash,
          amount: 100,
          currencyCode: 'USD',
        ),
      ]);

      await tester.pumpWidget(buildApp(trip: chinaTrip, repository: repo));
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      expect(find.textContaining('per USD'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), '100');
      await tester.pumpAndSettle();
      expect(find.textContaining('per USD'), findsNothing);

      await tester.enterText(find.byType(TextField).at(1), '720');
      await tester.pumpAndSettle();
      expect(find.textContaining('7.2 CNY per USD'), findsOneWidget);
    });

    testWidgets('shows add-cash recovery when no held currencies',
        (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(
        buildApp(
          trip: chinaTrip,
          repository: _BalancesCashWalletRepository(const []),
        ),
      );
      await tester.pumpAndSettle();
      await openExchangeSheet(tester);

      expect(find.text('Add cash first to exchange money.'), findsOneWidget);
      expect(find.text('Add Cash'), findsWidgets);
    });

    testWidgets('Exchange Office no longer appears in Add Cash create flow',
        (tester) async {
      sizeLarge(tester);
      await tester.pumpWidget(
        buildApp(
          trip: chinaTrip,
          repository: _BalancesCashWalletRepository(const []),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<CashTransactionType>));
      await tester.pumpAndSettle();

      expect(find.text('Exchange office'), findsNothing);
    });
  });
}

class _BalancesCashWalletRepository extends CashWalletRepository {
  _BalancesCashWalletRepository(
    this.balances, {
    this.transactions = const [],
  }) : super(AppDatabase());

  final List<TripCashBalance> balances;
  final List<CashTransaction> transactions;

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
