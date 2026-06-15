import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/presentation/refund_form_screen.dart';
import 'package:travel_expenses/features/refunds/presentation/trip_refunds_provider.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ux-2',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
    homeCurrencySnapshot: 'SAR',
  );

  final expenseWithHome = Expense.create(
    id: 'expense-home',
    tripId: trip.id,
    title: 'Restaurant',
    amount: 250,
    currencyCode: 'CNY',
    transactionAmount: 250,
    transactionCurrency: 'CNY',
    convertedHomeAmount: 130,
    homeCurrency: 'SAR',
    spentAt: DateTime(2026, 6, 1),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  final expenseWithoutHome = Expense.create(
    id: 'expense-plain',
    tripId: trip.id,
    title: 'Snack',
    amount: 20,
    currencyCode: 'CNY',
    transactionAmount: 20,
    transactionCurrency: 'CNY',
    spentAt: DateTime(2026, 6, 2),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  group('Sprint UX-2 — expense home amount visibility', () {
    testWidgets('expense card displays stored home amount', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [expenseWithHome],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restaurant'), findsOneWidget);
      expect(find.textContaining('250'), findsWidgets);
      expect(find.textContaining('CNY'), findsWidgets);
      expect(find.textContaining('130'), findsOneWidget);
      expect(find.textContaining('≈'), findsOneWidget);
    });

    testWidgets('home amount hidden when stored conversion is unavailable',
        (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [expenseWithoutHome],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Snack'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });
  });

  group('Sprint UX-2 — refund discoverability and visibility', () {
    testWidgets('refund action is visible in expense overflow menu', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [expenseWithHome],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Refund'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('refund action navigates to refund form', (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [expenseWithHome],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refund'));
      await tester.pumpAndSettle();

      expect(find.byType(RefundFormScreen), findsOneWidget);
      expect(find.text('Restaurant'), findsOneWidget);
    });

    testWidgets('expense with refund displays refunded amount', (tester) async {
      final refundedExpense = Expense.create(
        id: 'expense-refunded',
        tripId: trip.id,
        title: 'Souvenir shop',
        amount: 100,
        currencyCode: 'CNY',
        transactionAmount: 100,
        transactionCurrency: 'CNY',
        convertedHomeAmount: 52,
        homeCurrency: 'SAR',
        spentAt: DateTime(2026, 6, 3),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        category: 'Shopping',
      );

      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [refundedExpense],
          refunds: [
            ExpenseRefund.create(
              id: 'refund-1',
              tripId: trip.id,
              expenseId: refundedExpense.id,
              amount: 50,
              currencyCode: 'CNY',
              destination: RefundDestination.cash,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Refunded:'), findsOneWidget);
      expect(find.textContaining('Net:'), findsOneWidget);
      expect(find.textContaining('50'), findsWidgets);
    });

    testWidgets('expense without refund does not display refund section',
        (tester) async {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          expenses: [expenseWithHome],
          refunds: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Refunded:'), findsNothing);
    });
  });

  group('Sprint UX-2 — cash wallet home amount visibility', () {
    testWidgets('cash wallet entry displays stored home amount', (tester) async {
      await tester.pumpWidget(
        _buildCashWalletApp(
          trip: trip,
          transactions: [
            CashTransaction.create(
              id: 'initial-cash',
              tripId: trip.id,
              type: CashTransactionType.initialCash,
              amount: 10000,
              currencyCode: 'CNY',
              homeCurrencyAmount: 5200,
              homeCurrencyCode: 'SAR',
              createdAt: DateTime(2026, 6, 1, 10),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Initial cash'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Initial cash'), findsOneWidget);
      expect(find.textContaining('10,000'), findsWidgets);
      expect(find.textContaining('CNY'), findsWidgets);
      expect(find.textContaining('5,200'), findsOneWidget);
      expect(find.textContaining('≈'), findsOneWidget);
    });

    testWidgets('cash wallet entry hides home amount when unavailable',
        (tester) async {
      await tester.pumpWidget(
        _buildCashWalletApp(
          trip: trip,
          transactions: [
            CashTransaction.create(
              id: 'manual-no-home',
              tripId: trip.id,
              type: CashTransactionType.manualAdjustment,
              amount: 500,
              currencyCode: 'CNY',
              createdAt: DateTime(2026, 6, 1, 11),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Other cash added'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('500'), findsWidgets);
      expect(find.textContaining('≈'), findsNothing);
    });
  });
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required List<Expense> expenses,
  List<ExpenseRefund> refunds = const [],
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(
        _FakeExpenseRepository(initialExpenses: expenses),
      ),
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
      tripRefundsProvider(trip.id).overrideWith(
        (ref) => Future.value(refunds),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

Widget _buildCashWalletApp({
  required Trip trip,
  required List<CashTransaction> transactions,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(
        _FakeCashWalletRepository(transactions: transactions),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripCashWalletScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository({required List<Expense> initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository({required List<CashTransaction> transactions})
      : _transactions = transactions,
        super(AppDatabase());

  final List<CashTransaction> _transactions;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    final totals = <String, double>{};
    for (final transaction in _transactions.where((tx) => tx.tripId == tripId)) {
      totals.update(
        transaction.currencyCode,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    return totals.entries
        .map(
          (entry) => TripCashBalance(
            tripId: tripId,
            currencyCode: entry.key,
            balanceAmount: entry.value,
            updatedAt: DateTime.utc(2026, 6, 1),
          ),
        )
        .toList();
  }

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async {
    return _transactions.where((tx) => tx.tripId == tripId).toList();
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
