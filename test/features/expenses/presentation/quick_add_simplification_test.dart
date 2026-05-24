import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-quick-add',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('quick add displays trip base currency near amount field', (
    tester,
  ) async {
    final thbTrip = Trip.create(
      id: 'trip-thb',
      name: 'Thailand',
      destination: 'Bangkok',
      baseCurrency: 'THB',
    );

    await tester.pumpWidget(
      _buildQuickAddApp(
        trip: thbTrip,
        expenses: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Amount in THB'), findsOneWidget);
  });

  testWidgets(
    'quick add shows core fields without first-payment onboarding',
    (tester) async {
      await tester.pumpWidget(
        _buildQuickAddApp(
          trip: trip,
          expenses: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Quick Save'), findsOneWidget);
      expect(find.text('Add Details'), findsOneWidget);

      expect(find.text('How did you pay?'), findsNothing);
      expect(find.text('Do you want to add cash balance now?'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    },
  );

  testWidgets('quick save still submits from trip details', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository();

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(amountField, '18.5');
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Quick Save'));
    await tester.tap(find.text('Quick Save'));
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    expect(repository.createdExpenses.single.amount, 18.5);
    expect(repository.createdExpenses.single.category, 'Food');
    expect(repository.createdExpenses.single.currencyCode, 'CNY');
  });

  testWidgets('add details still opens expense form with prefill', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository();

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(amountField, '42');
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Details'));
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Transport'), findsOneWidget);

    final formAmountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(formAmountField.controller?.text, '42');
    expect(repository.createdExpenses, isEmpty);
  });
}

Widget _buildQuickAddApp({
  required Trip trip,
  required List<Expense> expenses,
}) {
  return ProviderScope(
    overrides: [
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: QuickAddExpenseSheet(trip: trip, expenses: expenses),
      ),
    ),
  );
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository() : super(AppDatabase());

  final List<Expense> createdExpenses = <Expense>[];

  @override
  Future<Expense> createExpense(Expense expense) async {
    createdExpenses.add(expense);
    return expense;
  }

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async => const [];
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
