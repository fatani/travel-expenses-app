import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-hierarchy',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
  );

  testWidgets('hides Add Expense FAB when expense list is empty', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add Expense'), findsNothing);
    expect(find.text('Add your first expense now'), findsOneWidget);
  });

  testWidgets('shows Add Expense FAB when at least one expense exists', (tester) async {
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
              paymentChannel: 'Cash',
              category: 'Food',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Repeat last expense'), findsOneWidget);
  });

  testWidgets('shows overflow menu in app bar with reports and export actions',
      (tester) async {
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
              paymentChannel: 'Cash',
              category: 'Food',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsNothing);
    expect(find.byIcon(Icons.file_download_outlined), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Trip report'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('overflow menu is present on empty trip details', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Trip report'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });
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
}
