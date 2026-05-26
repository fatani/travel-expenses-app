import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/sms_parser/presentation/sms_expense_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-hierarchy',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
  );

  final sampleExpense = Expense.create(
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
  );

  testWidgets('shows Add Expense FAB even when expense list is empty', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
    expect(find.text('Add your first expense now'), findsNothing);
    expect(find.text('Add Expense'), findsNothing);
  });

  testWidgets('shows Add Expense FAB when at least one expense exists', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byTooltip('Add Expense'), findsOneWidget);
  });

  testWidgets('Add Expense FAB opens fresh quick add, not repeat mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(find.text('Same as last time'), findsNothing);
  });

  testWidgets('repeat last expense is only inside quick add sheet', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Repeat last expense'), findsNothing);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('Repeat last expense'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Repeat last expense in quick add activates repeat mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    expect(find.text('Same as last time'), findsOneWidget);

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
    expect(
      tester.widget<TextField>(amountField).controller?.text,
      '25',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byType(QuickAddExpenseSheet),
              matching: find.byType(TextField).at(1),
            ),
          )
          .controller
          ?.text,
      'Lunch',
    );
  });

  testWidgets('does not show dashboard stat cards on trip details', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Top spending category'), findsNothing);
    expect(find.text('Expenses'), findsNothing);
    expect(find.text('Cash Wallet'), findsNothing);
  });

  testWidgets('shows overflow menu with edit trip instead of app bar edit icon',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Edit trip'), findsOneWidget);
    expect(find.text('Trip report'), findsOneWidget);
    expect(find.text('Add via Bank SMS'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('hides inline SMS button in active expense-list state', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add via Bank SMS'), findsNothing);
  });

  testWidgets('overflow menu SMS import opens SMS expense screen', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    final smsMenuItem = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      matching: find.text('Add via Bank SMS'),
    );
    expect(smsMenuItem, findsOneWidget);

    await tester.tap(smsMenuItem);
    await tester.pumpAndSettle();

    expect(find.byType(SmsExpenseScreen), findsOneWidget);
  });

  testWidgets('compact empty state has no inline SMS or cash wallet CTAs', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add via Bank SMS'), findsNothing);
    expect(find.text('Cash Wallet'), findsNothing);
    expect(find.text('Add First Expense'), findsNothing);
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
    expect(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        matching: find.text('Add via Bank SMS'),
      ),
      findsNothing,
    );
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required _FakeExpenseRepository repository,
  CashWalletRepository? cashWalletRepository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cashWalletRepositoryProvider.overrideWithValue(
        cashWalletRepository ?? _EmptyCashWalletRepository(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends TestExpenseRepository {
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
