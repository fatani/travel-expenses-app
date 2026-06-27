import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/refunds/domain/refund_result.dart';
import 'package:travel_expenses/features/refunds/presentation/trip_refund_form_screen.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/isolated_app_database.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final trip = Trip.create(
    id: 'trip-refund-entry',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'CNY',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 10),
  );

  final sampleExpense = Expense.create(
    id: 'expense-1',
    tripId: trip.id,
    title: 'Lunch',
    amount: 25,
    currencyCode: 'CNY',
    transactionAmount: 25,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 1, 2),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  final sampleCardExpense = Expense.create(
    id: 'expense-card-1',
    tripId: trip.id,
    title: 'Hotel',
    amount: 100,
    currencyCode: 'CNY',
    transactionAmount: 100,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 1, 3),
    paymentMethod: 'Credit Card',
    paymentChannel: 'POS Purchase',
    category: 'Lodging',
  );

  group('Trip-level refund entry point', () {
    testWidgets('overflow menu exposes Add Refund (English)', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(trip: trip, expenses: [sampleExpense]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Add Refund'), findsOneWidget);
    });

    testWidgets('overflow menu exposes Add Refund (Arabic)', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [sampleExpense],
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();

      expect(find.text('إضافة استرداد'), findsOneWidget);
    });

    testWidgets('Add Refund opens the trip refund form', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(trip: trip, expenses: [sampleExpense]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Refund'));
      await tester.pumpAndSettle();

      expect(find.byType(TripRefundFormScreen), findsOneWidget);
    });
  });

  group('Unlinked card refund form', () {
    testWidgets('saves an unlinked card refund with the right arguments',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();

      await tester.pumpWidget(
        _buildRefundFormApp(
          trip: trip,
          expenses: [sampleCardExpense],
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      // Card refund is the default refund type; leave it untouched.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '50',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.card);
      expect(spy.capturedExpenseId, isNull);
      expect(spy.capturedAmount, 50);
      expect(spy.capturedCurrency, 'CNY');
      // Home currency == refund currency → valued 1:1 so reports update.
      expect(spy.capturedHomeAmount, 50);
      expect(spy.capturedHomeCurrency, 'CNY');
    });
  });

  group('Trip refund default destination', () {
    Future<void> pumpAndSaveDefault(
      WidgetTester tester,
      List<Expense> expenses,
      _CapturingRecordRefundUseCase spy,
    ) async {
      await tester.pumpWidget(
        _buildRefundFormApp(
          trip: trip,
          expenses: expenses,
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();
    }

    testWidgets('cash-only expenses default to cash refund', (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSaveDefault(tester, [sampleExpense], spy);
      expect(spy.capturedDestination, RefundDestination.cash);
    });

    testWidgets('card expense defaults to card refund', (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSaveDefault(tester, [sampleCardExpense], spy);
      expect(spy.capturedDestination, RefundDestination.card);
    });

    testWidgets('mixed cash and card expenses default to card refund',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSaveDefault(
        tester,
        [sampleExpense, sampleCardExpense],
        spy,
      );
      expect(spy.capturedDestination, RefundDestination.card);
    });
  });

  group('Refund currency dropdown', () {
    final dropdownTrip = Trip.create(
      id: 'trip-currency-dropdown',
      name: 'Shanghai',
      destination: 'Shanghai',
      baseCurrency: 'CNY',
      destinationCurrency: 'CNY',
      homeCurrencySnapshot: 'SAR',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
    );

    final cardExpenseUsd = Expense.create(
      id: 'exp-card-usd',
      tripId: dropdownTrip.id,
      title: 'Hotel',
      amount: 100,
      currencyCode: 'USD',
      transactionAmount: 100,
      transactionCurrency: 'USD',
      spentAt: DateTime(2026, 1, 2),
      paymentMethod: 'Credit Card',
      paymentChannel: 'POS Purchase',
      category: 'Lodging',
    );

    final cashExpenseJpy = Expense.create(
      id: 'exp-cash-jpy',
      tripId: dropdownTrip.id,
      title: 'Snacks',
      amount: 500,
      currencyCode: 'JPY',
      transactionAmount: 500,
      transactionCurrency: 'JPY',
      spentAt: DateTime(2026, 1, 3),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );

    Future<void> pumpForm(WidgetTester tester, {RecordRefundUseCase? spy}) {
      return tester.pumpWidget(
        _buildRefundFormApp(
          trip: dropdownTrip,
          expenses: [cardExpenseUsd, cashExpenseJpy],
          recordRefundUseCase: spy ?? _CapturingRecordRefundUseCase(),
        ),
      );
    }

    testWidgets('currency control is a dropdown, not free-text', (tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      // No editable text field carries the currency label.
      expect(find.widgetWithText(TextFormField, 'Currency'), findsNothing);
    });

    testWidgets('defaults to the trip destination currency', (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpForm(tester, spy: spy);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedCurrency, 'CNY');
    });

    testWidgets('lists home, destination and prior card currencies only',
        (tester) async {
      await pumpForm(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      // Home (SAR) and prior card currency (USD) appear as selectable codes.
      expect(find.text('SAR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);
      // Cash-only currency is excluded; arbitrary currencies are not offered.
      expect(find.text('JPY'), findsNothing);
      expect(find.text('EUR'), findsNothing);
    });
  });

  group('Unlinked card refund persistence + reporting (real DB)', () {
    late AppDatabase db;
    late CashWalletRepository walletRepo;
    late CashLotRepository lotRepo;
    late ExpenseRefundRepository refundRepo;
    late ExpenseRepository expenseRepo;
    late RecordRefundUseCase useCase;

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'trip_refund_entry');
      walletRepo = CashWalletRepository(db);
      lotRepo = CashLotRepository(db);
      refundRepo = ExpenseRefundRepository(db);
      expenseRepo = ExpenseRepository(db);
      useCase = RecordRefundUseCase(
        appDatabase: db,
        refundEngine: const RefundInheritanceEngine(),
        refundRepository: refundRepo,
        lotRepository: lotRepo,
        cashWalletRepository: walletRepo,
      );
      await TripRepository(db).createTrip(trip);
    });

    tearDown(() async => db.close());

    test(
        'records unlinked card refund, leaves cash untouched, updates report',
        () async {
      // Gross spending 700 CNY (home currency CNY).
      final expenses = <Expense>[];
      for (var i = 0; i < 2; i++) {
        expenses.add(
          await expenseRepo.createExpense(
            Expense.create(
              tripId: trip.id,
              title: 'Card buy $i',
              amount: 350,
              currencyCode: 'CNY',
              transactionAmount: 350,
              transactionCurrency: 'CNY',
              convertedHomeAmount: 350,
              homeCurrency: 'CNY',
              spentAt: DateTime(2026, 1, i + 1),
              paymentMethod: 'Credit Card',
              paymentChannel: 'POS',
              category: 'Food',
            ),
          ),
        );
      }

      // Existing refunds = 150 CNY (linked card refund).
      await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expenses.first.id,
        refundAmount: 150,
        refundCurrency: 'CNY',
        homeAmount: 150,
        homeCurrency: 'CNY',
        linkedExpense: expenses.first,
      );

      // New unlinked card refund = 50 CNY.
      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: null,
        refundAmount: 50,
        refundCurrency: 'CNY',
        homeAmount: 50,
        homeCurrency: 'CNY',
      );

      // Refund record persisted as an unlinked card refund.
      expect(result.refund.expenseId, isNull);
      expect(result.refund.destination, RefundDestination.card);
      expect(result.refund.amount, 50);
      expect(result.refund.currencyCode, 'CNY');

      // No cash impact from a card refund.
      expect(result.cashLot, isNull);
      expect(result.cashTransaction, isNull);
      final transactions = await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(transactions, isEmpty);
      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances, isEmpty);

      // Report: gross 700, refunds 200, net 500.
      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      expect(refunds, hasLength(2));
      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
        refunds: refunds,
      );
      expect(summary.grossSpendingHomeAmount, closeTo(700, 0.01));
      expect(summary.refundHomeAmount, closeTo(200, 0.01));
      expect(summary.netSpendingHomeAmount, closeTo(500, 0.01));
    });
  });

  // ── Unlinked cash refund in non-home currency ─────────────────────────────

  group('Unlinked cash refund in non-home currency', () {
    final sarCnyTrip = Trip.create(
      id: 'trip-cash-refund-sar-cny',
      name: 'Beijing',
      destination: 'Beijing',
      baseCurrency: 'CNY',
      destinationCurrency: 'CNY',
      homeCurrencySnapshot: 'SAR',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
    );

    Future<void> pumpAndSwitchToCash(WidgetTester tester,
        _CapturingRecordRefundUseCase spy) async {
      await tester.pumpWidget(
        _buildRefundFormApp(
          trip: sarCnyTrip,
          expenses: [],
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
          find.byType(DropdownButtonFormField<RefundDestination>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash refund').last);
      await tester.pumpAndSettle();
    }

    testWidgets(
        'shows home value field when cash + unlinked + non-home currency',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSwitchToCash(tester, spy);

      expect(
        find.widgetWithText(
            TextFormField, 'Approximate value in home currency'),
        findsOneWidget,
      );
    });

    testWidgets('cannot save without home value — shows validation error',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSwitchToCash(tester, spy);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '100',
      );
      await tester.pumpAndSettle();

      // Leave home value empty and attempt to save
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter the approximate value in your home currency.'),
        findsOneWidget,
      );
      expect(spy.capturedDestination, isNull);
    });

    testWidgets('can save with home value — passes correct args to use case',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await pumpAndSwitchToCash(tester, spy);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
            TextFormField, 'Approximate value in home currency'),
        '52.5',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.cash);
      expect(spy.capturedExpenseId, isNull);
      expect(spy.capturedAmount, 100);
      expect(spy.capturedCurrency, 'CNY');
      expect(spy.capturedHomeAmount, closeTo(52.5, 0.01));
      expect(spy.capturedHomeCurrency, 'SAR');
    });
  });

  // ── Home-currency unlinked cash refund ────────────────────────────────────

  group('Home-currency unlinked cash refund', () {
    final sarCnyTrip = Trip.create(
      id: 'trip-cash-refund-home-cur',
      name: 'Beijing',
      destination: 'Beijing',
      baseCurrency: 'CNY',
      destinationCurrency: 'CNY',
      homeCurrencySnapshot: 'SAR',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
    );

    testWidgets(
        'does not show home value field; helper text shown; saves 1:1',
        (tester) async {
      final spy = _CapturingRecordRefundUseCase();
      await tester.pumpWidget(
        _buildRefundFormApp(
          trip: sarCnyTrip,
          expenses: [],
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Cash refund
      await tester.tap(
          find.byType(DropdownButtonFormField<RefundDestination>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash refund').last);
      await tester.pumpAndSettle();

      // Switch currency to SAR (home currency)
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAR').last);
      await tester.pumpAndSettle();

      // No home value INPUT field — currency equals home currency
      expect(
        find.widgetWithText(
            TextFormField, 'Approximate value in home currency'),
        findsNothing,
      );
      // Helper text indicating 1:1 valuation is shown
      expect(find.text('Same as home currency'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.cash);
      expect(spy.capturedCurrency, 'SAR');
      expect(spy.capturedHomeAmount, closeTo(100, 0.01));
      expect(spy.capturedHomeCurrency, 'SAR');
    });
  });

  // ── Unlinked cash refund — real DB ────────────────────────────────────────

  group('Unlinked cash refund — real DB', () {
    late AppDatabase db;
    late CashWalletRepository walletRepo;
    late CashLotRepository lotRepo;
    late ExpenseRefundRepository refundRepo;
    late RecordRefundUseCase useCase;

    final sarCnyTrip = Trip.create(
      id: 'trip-unlinked-cash-refund-db',
      name: 'Beijing',
      destination: 'Beijing',
      baseCurrency: 'CNY',
      destinationCurrency: 'CNY',
      homeCurrencySnapshot: 'SAR',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 10),
    );

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'unlinked_cash_refund');
      walletRepo = CashWalletRepository(db);
      lotRepo = CashLotRepository(db);
      refundRepo = ExpenseRefundRepository(db);
      useCase = RecordRefundUseCase(
        appDatabase: db,
        refundEngine: const RefundInheritanceEngine(),
        refundRepository: refundRepo,
        lotRepository: lotRepo,
        cashWalletRepository: walletRepo,
      );
      await TripRepository(db).createTrip(sarCnyTrip);
    });

    tearDown(() async => db.close());

    test('cash balance increases and lot is created with correct home basis',
        () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: sarCnyTrip.id,
        expenseId: null,
        refundAmount: 100,
        refundCurrency: 'CNY',
        homeAmount: 52.5,
        homeCurrency: 'SAR',
      );

      // Refund record
      expect(result.refund.expenseId, isNull);
      expect(result.refund.destination, RefundDestination.cash);
      expect(result.refund.amount, closeTo(100, 0.01));
      expect(result.refund.currencyCode, 'CNY');
      expect(result.refund.homeAmount, closeTo(52.5, 0.01));
      expect(result.refund.homeCurrency, 'SAR');

      // Cash lot
      expect(result.cashLot, isNotNull);
      expect(result.cashLot!.sourceType, 'cash_refund');
      expect(result.cashLot!.originalAmount, closeTo(100, 0.01));
      expect(result.cashLot!.remainingAmount, closeTo(100, 0.01));
      expect(result.cashLot!.currencyCode, 'CNY');
      expect(result.cashLot!.homeCurrencyAmount, closeTo(52.5, 0.01));
      expect(result.cashLot!.homeCurrencyCode, 'SAR');

      // Cash balance increased
      final balances = await walletRepo.getBalancesByTrip(sarCnyTrip.id);
      final cnyBalance =
          balances.firstWhere((b) => b.currencyCode == 'CNY');
      expect(cnyBalance.balanceAmount, closeTo(100, 0.01));
    });

    test('refund home amount recorded and queryable from repository',
        () async {
      await useCase.execute(
        destination: RefundDestination.cash,
        tripId: sarCnyTrip.id,
        expenseId: null,
        refundAmount: 100,
        refundCurrency: 'CNY',
        homeAmount: 52.5,
        homeCurrency: 'SAR',
      );

      final refunds =
          await refundRepo.getActiveRefundsByTrip(sarCnyTrip.id);
      expect(refunds, hasLength(1));
      expect(refunds.first.homeAmount, closeTo(52.5, 0.01));
      expect(refunds.first.homeCurrency, 'SAR');
    });

    test('card refund does not affect cash balance or create a lot',
        () async {
      await useCase.execute(
        destination: RefundDestination.card,
        tripId: sarCnyTrip.id,
        expenseId: null,
        refundAmount: 50,
        refundCurrency: 'CNY',
        homeAmount: 26.25,
        homeCurrency: 'SAR',
      );

      final balances = await walletRepo.getBalancesByTrip(sarCnyTrip.id);
      expect(balances, isEmpty);

      final lots = await lotRepo.getOpenLotsForCurrency(sarCnyTrip.id, 'CNY');
      expect(lots, isEmpty);
    });
  });
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required List<Expense> expenses,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(
        _FakeExpenseRepository(expenses),
      ),
      expenseRefundRepositoryProvider.overrideWithValue(_EmptyRefundRepository()),
      cashWalletRepositoryProvider.overrideWithValue(
        _EmptyCashWalletRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

Widget _buildRefundFormApp({
  required Trip trip,
  required List<Expense> expenses,
  required RecordRefundUseCase recordRefundUseCase,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      recordRefundUseCaseProvider.overrideWithValue(recordRefundUseCase),
      expenseRefundRepositoryProvider.overrideWithValue(_EmptyRefundRepository()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripRefundFormScreen(trip: trip, expenses: expenses),
    ),
  );
}

class _CapturingRecordRefundUseCase extends RecordRefundUseCase {
  _CapturingRecordRefundUseCase()
      : super(
          appDatabase: AppDatabase(),
          refundEngine: const RefundInheritanceEngine(),
          refundRepository: ExpenseRefundRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
        );

  RefundDestination? capturedDestination;
  String? capturedExpenseId;
  double? capturedAmount;
  String? capturedCurrency;
  double? capturedHomeAmount;
  String? capturedHomeCurrency;

  @override
  Future<RefundResult> execute({
    required RefundDestination destination,
    required String tripId,
    String? expenseId,
    required double refundAmount,
    required String refundCurrency,
    double? homeAmount,
    String? homeCurrency,
    String? note,
    DateTime? createdAt,
    Expense? linkedExpense,
  }) async {
    capturedDestination = destination;
    capturedExpenseId = expenseId;
    capturedAmount = refundAmount;
    capturedCurrency = refundCurrency;
    capturedHomeAmount = homeAmount;
    capturedHomeCurrency = homeCurrency;
    return RefundResult(
      refund: ExpenseRefund.create(
        id: 'captured-refund',
        tripId: tripId,
        expenseId: expenseId,
        amount: refundAmount,
        currencyCode: refundCurrency,
        homeAmount: homeAmount,
        homeCurrency: homeCurrency,
        destination: destination,
      ),
    );
  }
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async =>
      _expenses.where((expense) => expense.tripId == tripId).toList();
}

class _EmptyRefundRepository extends ExpenseRefundRepository {
  _EmptyRefundRepository() : super(AppDatabase());

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByTrip(String tripId) async =>
      const [];
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());

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
}
