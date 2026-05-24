import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-search-visibility',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
  );

  testWidgets('hides search bar when expense count is below 5', (tester) async {
    for (final count in [1, 2, 3, 4]) {
      await tester.pumpWidget(
        _buildTripDetailsApp(
          trip: trip,
          repository: _FakeExpenseRepository(
            initialExpenses: _sampleExpenses(trip.id, count),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Search by title, description, or merchant'),
        findsNothing,
        reason: 'search hint should be hidden for $count expenses',
      );
      expect(
        find.byIcon(Icons.search_rounded),
        findsNothing,
        reason: 'search icon should be hidden for $count expenses',
      );
      expect(
        find.byIcon(Icons.tune_rounded),
        findsNothing,
        reason: 'filter icon should be hidden for $count expenses',
      );
    }
  });

  testWidgets('shows search bar when expense count reaches 5', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: _sampleExpenses(trip.id, 5),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.search_rounded),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('search filters expenses when search bar is visible', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [
            Expense.create(
              id: 'expense-1',
              tripId: trip.id,
              title: 'Lunch',
              amount: 25,
              currencyCode: 'CNY',
              transactionAmount: 25,
              transactionCurrency: 'CNY',
              spentAt: DateTime(2026, 5, 16),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
            Expense.create(
              id: 'expense-2',
              tripId: trip.id,
              title: 'Dinner',
              amount: 40,
              currencyCode: 'CNY',
              transactionAmount: 40,
              transactionCurrency: 'CNY',
              spentAt: DateTime(2026, 5, 15),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
            Expense.create(
              id: 'expense-3',
              tripId: trip.id,
              title: 'Coffee',
              amount: 8,
              currencyCode: 'CNY',
              transactionAmount: 8,
              transactionCurrency: 'CNY',
              spentAt: DateTime(2026, 5, 14),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
            Expense.create(
              id: 'expense-4',
              tripId: trip.id,
              title: 'Taxi',
              amount: 15,
              currencyCode: 'CNY',
              transactionAmount: 15,
              transactionCurrency: 'CNY',
              spentAt: DateTime(2026, 5, 13),
              paymentMethod: 'Cash',
              category: 'Transport',
            ),
            Expense.create(
              id: 'expense-5',
              tripId: trip.id,
              title: 'Hotel',
              amount: 120,
              currencyCode: 'CNY',
              transactionAmount: 120,
              transactionCurrency: 'CNY',
              spentAt: DateTime(2026, 5, 12),
              paymentMethod: 'Credit Card',
              category: 'Lodging',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lunch'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Hotel'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(TextField),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.pumpAndSettle();

    expect(find.text('Dinner'), findsNothing);
    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Taxi'), findsNothing);
    expect(find.text('Hotel'), findsNothing);
  });
}

List<Expense> _sampleExpenses(String tripId, int count) {
  return List.generate(
    count,
    (index) => Expense.create(
      id: 'expense-$index',
      tripId: tripId,
      title: 'Expense $index',
      amount: 10.0 + index,
      currencyCode: 'CNY',
      transactionAmount: 10.0 + index,
      transactionCurrency: 'CNY',
      spentAt: DateTime(2026, 5, 16).subtract(Duration(days: index)),
      paymentMethod: 'Cash',
      category: 'Food',
    ),
  );
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required _FakeExpenseRepository repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
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
