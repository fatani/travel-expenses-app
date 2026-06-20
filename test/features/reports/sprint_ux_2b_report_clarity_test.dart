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
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/data/trip_report_provider.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_display.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../support/test_expense_repository.dart';

Future<void> _scrollToSection(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Sprint UX-2B — report clarity', () {
    late Trip trip;
    late List<Expense> expenses;
    late List<ExpenseRefund> refunds;

    setUp(() {
      trip = Trip.create(
        id: 'trip-ux2b',
        name: 'Shanghai',
        destination: 'Shanghai',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 10),
      );

      expenses = List<Expense>.generate(
        4,
        (index) => Expense.create(
          id: 'exp-$index',
          tripId: trip.id,
          title: 'Expense $index',
          amount: index == 0 ? 890 : 500,
          currencyCode: 'CNY',
          transactionAmount: index == 0 ? 890 : 500,
          transactionCurrency: 'CNY',
          convertedHomeAmount: index == 0 ? 462.8 : 260,
          homeCurrency: 'SAR',
          spentAt: DateTime(2026, 1, index + 1),
          paymentMethod: 'Credit Card',
          paymentChannel: 'POS',
          category: 'Food',
        ),
      );

      refunds = [
        ExpenseRefund.create(
          id: 'refund-1',
          tripId: trip.id,
          expenseId: expenses.first.id,
          amount: 400,
          currencyCode: 'CNY',
          homeAmount: 208,
          homeCurrency: 'SAR',
          destination: RefundDestination.card,
        ),
      ];
    });

    test('provider assembles refund-by-currency display buckets', () async {
      final container = ProviderContainer(
        overrides: [
          tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(expenses),
          ),
          expenseRefundRepositoryProvider.overrideWithValue(
            _FakeRefundRepository(refunds),
          ),
          cashWalletRepositoryProvider.overrideWithValue(
            _FakeCashWalletRepository(),
          ),
          cashLotRepositoryProvider.overrideWithValue(
            _FakeCashLotRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final display =
          await container.read(tripReportProvider(trip.id).future);

      expect(display, isA<TripReportDisplay>());
      expect(display.refundsByTransactionCurrency, hasLength(1));
      expect(display.refundsByTransactionCurrency.single.totalAmount, 400);
      expect(display.refundsByTransactionCurrency.single.currency, 'CNY');
      expect(display.summary.totalBilledByCurrency.single.totalAmount, 2390);
    });

    test('calculator math unchanged after display assembly', () {
      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
        refunds: refunds,
      );

      expect(summary.grossSpendingHomeAmount, closeTo(1242.8, 0.01));
      expect(summary.refundHomeAmount, closeTo(208, 0.01));
      expect(summary.netSpendingHomeAmount, closeTo(1034.8, 0.01));
      expect(summary.totalBilledByCurrency.single.totalAmount, 2390);
    });

    testWidgets('top card shows gross, refunds, and net in trip currency',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(refunds),
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

      expect(find.text('Gross expenses'), findsOneWidget);
      expect(find.textContaining('2,390'), findsOneWidget);
      expect(find.textContaining('400'), findsWidgets);
      expect(find.textContaining('1,990'), findsOneWidget);
    });

    testWidgets('gross-by-currency section uses truthful label', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(refunds),
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

      await _scrollToSection(tester, 'Gross spending by currency');

      expect(find.text('Gross spending by currency'), findsOneWidget);
      expect(find.text('Spending by currency'), findsNothing);
    });

    testWidgets('refunds-by-currency section shown when refunds exist',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(refunds),
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

      await _scrollToSection(tester, 'Refunds by currency');

      expect(find.text('Refunds by currency'), findsOneWidget);
    });

    testWidgets('refunds-by-currency section hidden without refunds',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(const []),
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

      await _scrollToSection(tester, 'Gross spending by currency');

      expect(find.text('Refunds by currency'), findsNothing);
    });

    // -----------------------------------------------------------------------
    // Home-currency clarity polish
    // -----------------------------------------------------------------------

    testWidgets('home-currency summary shows helper subtitle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(refunds),
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

      await _scrollToSection(tester, 'Spending Summary in Your Home Currency');

      expect(
        find.textContaining(
          'Shows only items with a completed value in your home currency',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no pending warning when all home values are complete',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
            expenseRepositoryProvider.overrideWithValue(
              _FakeExpenseRepository(expenses),
            ),
            expenseRefundRepositoryProvider.overrideWithValue(
              _FakeRefundRepository(refunds),
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

      // All test expenses have convertedHomeAmount set, so count == 0.
      expect(find.textContaining('Home-currency note'), findsNothing);
    });

    test('calculator math unchanged after home-currency clarity polish', () {
      const calculator = TripReportCalculator();
      final summary = calculator.calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: expenses,
        refunds: refunds,
      );

      expect(summary.grossSpendingHomeAmount, closeTo(1242.8, 0.01));
      expect(summary.refundHomeAmount, closeTo(208, 0.01));
      expect(summary.netSpendingHomeAmount, closeTo(1034.8, 0.01));
      expect(summary.totalBilledByCurrency.single.totalAmount, 2390);
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
