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
          expenses: [sampleExpense],
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
