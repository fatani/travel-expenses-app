import 'package:sqflite/sqflite.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
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

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('THB'),
      ),
      findsOneWidget,
    );
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

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Cash'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(QuickAddExpenseSheet),
          matching: find.widgetWithText(ChoiceChip, 'Card'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(QuickAddExpenseSheet),
          matching: find.widgetWithText(ChoiceChip, 'Other'),
        ),
        findsOneWidget,
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Add Details'), findsOneWidget);
      expect(find.text('...'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);

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
      matching: find.byType(TextField).first,
    );
    await tester.enterText(amountField, '18.5');
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
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
      matching: find.byType(TextField).first,
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

  testWidgets('amount field requests focus when quick add opens', (tester) async {
    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: const []),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final amountField = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountField.focusNode?.hasFocus, isTrue);
  });

  testWidgets('save button stays visible without scrolling in common layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: const []),
    );
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save');
    expect(saveButton, findsOneWidget);
    expect(tester.getBottomLeft(saveButton).dy, greaterThan(0));
  });

  testWidgets('quick add saves with amount only using defaults', (tester) async {
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
      matching: find.byType(TextField).first,
    );
    await tester.enterText(amountField, '9.75');
    await tester.pumpAndSettle();
    final saveButton = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.widgetWithText(FilledButton, 'Save'),
    );
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    expect(repository.createdExpenses.single.amount, 9.75);
    expect(repository.createdExpenses.single.category, 'Food');
    expect(repository.createdExpenses.single.paymentMethod, 'Cash');
  });

  testWidgets('add details is a secondary text action not a second primary button',
      (tester) async {
    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: const []),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.widgetWithText(TextButton, 'Add Details'),
      ),
      findsOneWidget,
    );
    expect(find.text('Add Details'), findsOneWidget);
  });

  testWidgets('arabic quick add keeps amount LTR and shows localized save',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuickAddExpenseSheet(trip: trip, expenses: const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountField.textDirection, TextDirection.ltr);
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.text('إضافة تفاصيل'), findsOneWidget);
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

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository() : super(AppDatabase());

  final List<Expense> createdExpenses = <Expense>[];

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
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
