import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_currency_summary.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/refunds/presentation/linked_refund_home_snapshot.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/isolated_app_database.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Sprint UX-2A — card refund home snapshot', () {
    test('linked snapshot returns null pair when conversion data is missing', () {
      final expense = Expense.create(
        id: 'exp-no-conversion',
        tripId: 'trip-1',
        title: 'Card purchase',
        amount: 250,
        currencyCode: 'CNY',
        transactionAmount: 250,
        transactionCurrency: 'CNY',
        homeCurrency: 'SAR',
        spentAt: DateTime(2026, 6, 1),
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS',
        category: 'Food',
      );

      final snapshot = linkedRefundHomeSnapshot(
        expense: expense,
        refundAmount: 100,
      );

      expect(snapshot.homeAmount, isNull);
      expect(snapshot.homeCurrency, isNull);
    });
  });

  group('Sprint UX-2A — card refund use case', () {
    late AppDatabase db;
    late TripRepository tripRepo;
    late CashWalletRepository walletRepo;
    late CashLotRepository lotRepo;
    late ExpenseRefundRepository refundRepo;
    late ExpenseRepository expenseRepo;
    late RecordRefundUseCase useCase;
    late Trip trip;

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'ux2a_card_refund');
      tripRepo = TripRepository(db);
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
      trip = await tripRepo.createTrip(
        Trip.create(
          id: 'trip-ux2a',
          name: 'Shanghai',
          destination: 'Shanghai',
          baseCurrency: 'CNY',
          destinationCurrency: 'CNY',
          homeCurrencySnapshot: 'SAR',
        ),
      );
    });

    tearDown(() async => db.close());

    Future<Expense> createCardExpense({
      double amount = 890,
      double? convertedHomeAmount = 462.8,
    }) {
      return expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'Restaurant',
          amount: amount,
          currencyCode: 'CNY',
          transactionAmount: amount,
          transactionCurrency: 'CNY',
          convertedHomeAmount: convertedHomeAmount,
          homeCurrency: convertedHomeAmount != null ? 'SAR' : null,
          spentAt: DateTime(2026, 6, 1),
          paymentMethod: 'Credit Card',
          paymentChannel: 'POS',
          category: 'Food',
        ),
      );
    }

    test('card refund creates expense_refunds row', () async {
      final expense = await createCardExpense();

      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 400,
        refundCurrency: 'CNY',
        linkedExpense: expense,
      );

      expect(result.refund.destination, RefundDestination.card);
      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      expect(refunds, hasLength(1));
      expect(refunds.first.id, result.refund.id);
    });

    test('card refund creates no cash lot', () async {
      final expense = await createCardExpense();

      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 400,
        refundCurrency: 'CNY',
        linkedExpense: expense,
      );

      expect(result.cashLot, isNull);
      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'CNY');
      expect(lots, isEmpty);
    });

    test('card refund creates no cash transaction', () async {
      final expense = await createCardExpense();

      await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 400,
        refundCurrency: 'CNY',
        linkedExpense: expense,
      );

      final transactions =
          await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(transactions, isEmpty);
    });

    test('card refund with missing conversion still succeeds', () async {
      final expense = await createCardExpense(convertedHomeAmount: null);

      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 100,
        refundCurrency: 'CNY',
        linkedExpense: expense,
      );

      expect(result.refund.homeAmount, isNull);
      expect(result.cashLot, isNull);
    });

    test('card refund reduces net spending in TripReportSummary', () async {
      final expense = await createCardExpense(amount: 890, convertedHomeAmount: 462.8);

      await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 400,
        refundCurrency: 'CNY',
        linkedExpense: expense,
      );

      final expenses = await expenseRepo.getExpensesByTrip(trip.id);
      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
        refunds: refunds,
      );

      expect(summary.grossSpendingHomeAmount, closeTo(462.8, 0.01));
      expect(summary.refundHomeAmount, isNotNull);
      expect(summary.refundHomeAmount!, greaterThan(0));
      expect(summary.netSpendingHomeAmount, lessThan(summary.grossSpendingHomeAmount!));
    });
  });

  group('Sprint UX-2A — cash refund net spending', () {
    late AppDatabase db;
    late TripRepository tripRepo;
    late CashWalletRepository walletRepo;
    late CashLotRepository lotRepo;
    late ExpenseRefundRepository refundRepo;
    late ExpenseRepository expenseRepo;
    late RecordRefundUseCase useCase;
    late Trip trip;

    setUp(() async {
      db = createIsolatedAppDatabase(prefix: 'ux2a_cash_refund');
      tripRepo = TripRepository(db);
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
      trip = await tripRepo.createTrip(
        Trip.create(
          id: 'trip-cash-ux2a',
          name: 'Tokyo',
          destination: 'Tokyo',
          baseCurrency: 'JPY',
          destinationCurrency: 'JPY',
          homeCurrencySnapshot: 'SAR',
        ),
      );
    });

    tearDown(() async => db.close());

    test('cash refund still creates lot and transaction and reduces net spending',
        () async {
      final expense = await expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'Cash meal',
          amount: 1000,
          currencyCode: 'JPY',
          transactionAmount: 1000,
          transactionCurrency: 'JPY',
          convertedHomeAmount: 27,
          homeCurrency: 'SAR',
          spentAt: DateTime(2026, 6, 1),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      );

      expect(result.cashLot, isNotNull);
      expect(result.cashTransaction, isNotNull);
      expect(result.refund.returnedLotId, result.cashLot!.id);

      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: [expense],
        refunds: [result.refund],
      );

      expect(summary.refundHomeAmount, closeTo(13.5, 0.01));
      expect(summary.netSpendingHomeAmount, closeTo(13.5, 0.01));
    });
  });

  group('Sprint UX-2A — trip report UI', () {
    testWidgets('displays gross spending, refunds, and net spending', (tester) async {
      final trip = Trip.create(
        id: 'trip-report-ui',
        name: 'Shanghai',
        destination: 'Shanghai',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
      );

      final expenses = List<Expense>.generate(
        4,
        (index) => Expense.create(
          id: 'exp-$index',
          tripId: trip.id,
          title: 'Expense $index',
          amount: 250,
          currencyCode: 'CNY',
          transactionAmount: 250,
          transactionCurrency: 'CNY',
          convertedHomeAmount: 130,
          homeCurrency: 'SAR',
          spentAt: DateTime(2026, 1, index + 1),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository([
                ExpenseRefund.create(
                  id: 'refund-1',
                  tripId: trip.id,
                  expenseId: expenses.first.id,
                  amount: 100,
                  currencyCode: 'CNY',
                  homeAmount: 52,
                  homeCurrency: 'SAR',
                  destination: RefundDestination.card,
                ),
              ]),
            ),
            cashWalletRepositoryProvider.overrideWithValue(
              _FakeCashWalletRepository(),
            ),
            cashLotRepositoryProvider.overrideWithValue(
              _FakeCashLotRepository(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripReportsScreen(trip: trip),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Gross spending'), findsOneWidget);
      expect(find.text('Refunds'), findsOneWidget);
      expect(find.text('Net spending'), findsOneWidget);
      expect(find.textContaining('520'), findsWidgets);
      expect(find.textContaining('52'), findsWidgets);
      expect(find.textContaining('468'), findsOneWidget);
    });
  });
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository(this._trip) : super(AppDatabase());

  final Trip _trip;

  @override
  Future<Trip?> getTripById(String id) async => id == _trip.id ? _trip : null;
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async =>
      _expenses.where((expense) => expense.tripId == tripId).toList();
}

class _FakeRefundRepository extends ExpenseRefundRepository {
  _FakeRefundRepository(this._refunds) : super(AppDatabase());

  final List<ExpenseRefund> _refunds;

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByTrip(String tripId) async =>
      _refunds.where((refund) => refund.tripId == tripId).toList();
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository() : super(AppDatabase());
}

class _FakeCashLotRepository extends CashLotRepository {
  _FakeCashLotRepository() : super(AppDatabase());

  @override
  Future<List<CashLotCurrencySummary>> computeLotCurrencySummaries({
    required String tripId,
    required String homeCurrencyCode,
  }) async =>
      const [];

  @override
  Future<List<CashLot>> getActiveLotsForTrip(String tripId) async => const [];
}
