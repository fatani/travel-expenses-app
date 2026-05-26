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
    id: 'trip-payment-clarity',
    name: 'Clarity Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('quick add shows only cash card and other payment chips',
      (tester) async {
    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.widgetWithText(ChoiceChip, 'Cash'),
      ),
      findsOneWidget,
    );
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
    expect(find.text('Visa'), findsNothing);
    expect(find.text('Mastercard'), findsNothing);
    expect(find.text('Mada'), findsNothing);
    expect(find.text('Apple Pay'), findsNothing);
    expect(find.text('Google Pay'), findsNothing);
    expect(find.textContaining('****'), findsNothing);
  });

  testWidgets('payment default selects card when last trip expense was card-like',
      (tester) async {
    final older = Expense.create(
      id: 'exp-old',
      tripId: trip.id,
      title: 'Cash meal',
      amount: 5,
      currencyCode: 'CNY',
      spentAt: DateTime(2026, 5, 10),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
    );
    final newer = Expense.create(
      id: 'exp-new',
      tripId: trip.id,
      title: 'Card taxi',
      amount: 12,
      currencyCode: 'CNY',
      spentAt: DateTime(2026, 5, 20),
      paymentMethod: 'Credit Card',
      paymentChannel: 'POS Purchase',
      paymentNetwork: 'Visa',
      cardProfileId: 1,
    );

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: [older, newer]),
    );
    await tester.pumpAndSettle();

    final cardChip = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.widgetWithText(ChoiceChip, 'Card'),
    );
    expect(tester.widget<ChoiceChip>(cardChip).selected, isTrue);
  });

  testWidgets('repeat last normalizes visa expense to card chip', (tester) async {
    final lastExpense = Expense.create(
      id: 'exp-visa',
      tripId: trip.id,
      title: 'Store',
      amount: 40,
      currencyCode: 'CNY',
      spentAt: DateTime(2026, 5, 18),
      paymentMethod: 'Credit Card',
      paymentChannel: 'Apple Pay',
      paymentNetwork: 'Visa',
      cardProfileId: 2,
    );

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: [lastExpense]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    final cardChip = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.widgetWithText(ChoiceChip, 'Card'),
    );
    expect(tester.widget<ChoiceChip>(cardChip).selected, isTrue);
    expect(find.text('Visa'), findsNothing);
  });

  testWidgets('add details transfers card selection to expense form',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository();

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.widgetWithText(ChoiceChip, 'Card'),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
    await tester.enterText(amountField, '15');
    await tester.ensureVisible(find.text('Add Details'));
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(repository.createdExpenses, isEmpty);
  });

  testWidgets('arabic quick add shows localized payment chips', (tester) async {
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

    final sheet = find.byType(QuickAddExpenseSheet);
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(ChoiceChip, 'نقداً'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(ChoiceChip, 'بطاقة'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(ChoiceChip, 'أخرى'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('payment row stays compact on narrow width', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
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
  required _FakeExpenseRepository repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
    ],
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
