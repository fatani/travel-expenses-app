import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_currency_summary.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/refunds/domain/refund_result.dart';
import 'package:travel_expenses/features/refunds/presentation/refund_form_screen.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ux2c',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 10),
  );

  final cashExpense = Expense.create(
    id: 'exp-cash',
    tripId: trip.id,
    title: 'Street food',
    amount: 200,
    currencyCode: 'CNY',
    transactionAmount: 200,
    transactionCurrency: 'CNY',
    convertedHomeAmount: 104,
    homeCurrency: 'SAR',
    spentAt: DateTime(2026, 6, 1),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  final cardExpense = Expense.create(
    id: 'exp-card',
    tripId: trip.id,
    title: 'Restaurant',
    amount: 890,
    currencyCode: 'CNY',
    transactionAmount: 890,
    transactionCurrency: 'CNY',
    convertedHomeAmount: 462.8,
    homeCurrency: 'SAR',
    spentAt: DateTime(2026, 6, 2),
    paymentMethod: 'Credit Card',
    paymentChannel: 'POS',
    category: 'Food',
  );

  group('Sprint UX-2C — cash refund destination', () {
    testWidgets('hides destination selector for cash expenses', (tester) async {
      await tester.pumpWidget(
        _buildRefundForm(trip: trip, expense: cashExpense),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refund destination'), findsNothing);
      expect(find.text('Cash wallet'), findsNothing);
      expect(find.text('Card'), findsNothing);
    });

    testWidgets('submits cash expense refund to cash wallet', (tester) async {
      final spy = _CapturingRecordRefundUseCase();

      await tester.pumpWidget(
        _buildRefundForm(
          trip: trip,
          expense: cashExpense,
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '100',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.cash);
    });
  });

  group('Sprint UX-2C — card refund destination', () {
    testWidgets('shows destination selector for card expenses', (tester) async {
      await tester.pumpWidget(
        _buildRefundForm(trip: trip, expense: cardExpense),
      );
      await tester.pumpAndSettle();

      expect(find.text('Refund destination'), findsOneWidget);
      expect(find.text('Card'), findsWidgets);
      expect(find.byType(DropdownButtonFormField<RefundDestination>), findsOneWidget);
    });

    testWidgets('supports card destination selection', (tester) async {
      final spy = _CapturingRecordRefundUseCase();

      await tester.pumpWidget(
        _buildRefundForm(
          trip: trip,
          expense: cardExpense,
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '200',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.card);
    });

    testWidgets('supports cash wallet destination selection', (tester) async {
      final spy = _CapturingRecordRefundUseCase();

      await tester.pumpWidget(
        _buildRefundForm(
          trip: trip,
          expense: cardExpense,
          recordRefundUseCase: spy,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<RefundDestination>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash wallet').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '200',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      expect(spy.capturedDestination, RefundDestination.cash);
    });
  });

  group('Sprint UX-2C — refund home value hint', () {
    testWidgets('shows inherited home value when available', (tester) async {
      await tester.pumpWidget(
        _buildRefundForm(trip: trip, expense: cashExpense),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('original cost basis'),
        findsNothing,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Refund amount'),
        '200',
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('original cost basis'),
        findsOneWidget,
      );
      expect(find.textContaining('104'), findsOneWidget);
      expect(find.textContaining('SAR'), findsWidgets);
    });
  });

  group('Sprint UX-2C — edit expense guidance', () {
    testWidgets('shows refund guidance on edit screen only', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExpenseFormScreen(trip: trip, expense: cashExpense),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If you received a partial or full refund, use Refund instead of changing the expense amount.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides refund guidance on create screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ExpenseFormScreen(trip: trip),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'If you received a partial or full refund, use Refund instead of changing the expense amount.',
        ),
        findsNothing,
      );
    });
  });

  group('Sprint UX-2C — home currency summary title', () {
    testWidgets('shows home currency summary title on report', (tester) async {
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
              _FakeRefundRepository(),
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

      expect(
        find.text('Spending Summary in Your Home Currency'),
        findsOneWidget,
      );
    });
  });
}

Widget _buildRefundForm({
  required Trip trip,
  required Expense expense,
  RecordRefundUseCase? recordRefundUseCase,
}) {
  return ProviderScope(
    overrides: [
      if (recordRefundUseCase != null)
        recordRefundUseCaseProvider.overrideWithValue(recordRefundUseCase),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: RefundFormScreen(trip: trip, expense: expense),
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
  _FakeRefundRepository() : super(AppDatabase());

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByTrip(String tripId) async =>
      const [];
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
