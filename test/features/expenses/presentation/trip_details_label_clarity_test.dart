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
    id: 'trip-labels',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
  );

  testWidgets('does not show card charges dashboard stat on trip details',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'intl-1',
          tripId: trip.id,
          title: 'Bangkok ride',
          amount: 10,
          currencyCode: 'THB',
          transactionAmount: 10,
          transactionCurrency: 'THB',
          totalChargedAmount: 1.20,
          totalChargedCurrency: 'SAR',
          isInternational: true,
          spentAt: DateTime(2026, 4, 13),
          paymentMethod: 'Credit Card',
          category: 'Transport',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Card charges in SAR'), findsNothing);
    expect(find.text('Total in SAR only'), findsNothing);
  });

  testWidgets('single-currency trip shows subtle total in context strip only',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'e1',
          tripId: trip.id,
          title: 'Lunch',
          amount: 10,
          currencyCode: 'CNY',
          transactionAmount: 10,
          transactionCurrency: 'CNY',
          spentAt: DateTime(2026, 4, 12),
          paymentMethod: 'Cash',
          category: 'Food',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Total expenses:'), findsOneWidget);
    expect(find.textContaining('10 CNY'), findsOneWidget); // subtle strip total
    expect(find.text('Top spending category'), findsNothing);
    expect(find.text('Expenses logged'), findsNothing);
  });

  testWidgets('multi-currency trip hides combined total from context strip',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'e1',
          tripId: trip.id,
          title: 'Lunch',
          amount: 10,
          currencyCode: 'CNY',
          transactionAmount: 10,
          transactionCurrency: 'CNY',
          spentAt: DateTime(2026, 4, 12),
          paymentMethod: 'Cash',
          category: 'Food',
        ),
        Expense.create(
          id: 'e2',
          tripId: trip.id,
          title: 'Taxi',
          amount: 20,
          currencyCode: 'SAR',
          transactionAmount: 20,
          transactionCurrency: 'SAR',
          spentAt: DateTime(2026, 4, 12),
          paymentMethod: 'Cash',
          category: 'Transport',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Total expenses:'), findsNothing);
    expect(find.text('Mixed currencies'), findsNothing);
    expect(
      find.text(
        'Some expenses in other currencies are not included in the totals above',
      ),
      findsNothing,
    );
  });

  testWidgets('Arabic locale keeps compressed strip without dashboard stats',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'e1',
          tripId: trip.id,
          title: 'Lunch',
          amount: 50,
          currencyCode: 'CNY',
          transactionAmount: 50,
          transactionCurrency: 'CNY',
          spentAt: DateTime(2026, 4, 12),
          paymentMethod: 'Cash',
          category: 'Food',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('إجمالي المصاريف'), findsOneWidget);
    expect(find.text('أعلى فئة إنفاق'), findsNothing);
    expect(find.text('إضافة مصروف'), findsNothing);
    expect(find.text('كرر آخر مصروف'), findsNothing);
  });
}

Widget _buildApp({
  required Widget child,
  List<Override> overrides = const [],
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
      ...overrides,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
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
