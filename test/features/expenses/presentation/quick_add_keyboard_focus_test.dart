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
    id: 'trip-keyboard',
    name: 'Keyboard Trip',
    destination: 'Test',
    baseCurrency: 'USD',
  );

  final baseTime = DateTime(2026, 5, 20, 12);

  Expense expense({
    required String id,
    required String title,
    required DateTime spentAt,
  }) {
    return Expense.create(
      id: id,
      tripId: trip.id,
      title: title,
      amount: 10,
      currencyCode: 'USD',
      category: 'Food',
      spentAt: spentAt,
      paymentMethod: 'Cash',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder amountField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  Finder merchantField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).at(1),
    );
  }

  testWidgets('amount field requests focus when quick add opens', (tester) async {
    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final amount = tester.widget<TextField>(amountField());
    expect(amount.focusNode?.hasFocus, isTrue);
    expect(amount.autofocus, isFalse);
  });

  testWidgets('merchant field does not autofocus on open', (tester) async {
    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final merchant = tester.widget<TextField>(merchantField());
    expect(merchant.focusNode?.hasFocus, isFalse);
  });

  testWidgets('tapping merchant field focuses merchant', (tester) async {
    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    await tester.tap(merchantField());
    await tester.pump();

    final merchant = tester.widget<TextField>(merchantField());
    expect(merchant.focusNode?.hasFocus, isTrue);
  });

  testWidgets('keyboard done on valid amount saves expense', (tester) async {
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

    await tester.enterText(amountField(), '15.25');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    expect(repository.createdExpenses.single.amount, 15.25);
  });

  testWidgets('keyboard done on empty amount does not save', (tester) async {
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

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, isEmpty);
    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
  });

  testWidgets('keyboard done on invalid amount does not save', (tester) async {
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

    await tester.enterText(amountField(), '0');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, isEmpty);
    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
  });

  testWidgets('merchant chip fills merchant without clearing amount', (tester) async {
    final tripExpenses = [
      expense(id: '1', title: 'River Cafe', spentAt: baseTime),
    ];

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: tripExpenses),
    );
    await tester.pumpAndSettle();

    await tester.enterText(amountField(), '22');
    await tester.pumpAndSettle();
    await tester.tap(find.text('River Cafe'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(amountField()).controller?.text,
      '22',
    );
    expect(
      tester.widget<TextField>(merchantField()).controller?.text,
      'River Cafe',
    );
  });

  testWidgets('category and payment chips do not reset amount or merchant',
      (tester) async {
    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    await tester.enterText(amountField(), '18');
    await tester.enterText(merchantField(), 'Station Shop');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.widgetWithText(ChoiceChip, 'Card'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(amountField()).controller?.text,
      '18',
    );
    expect(
      tester.widget<TextField>(merchantField()).controller?.text,
      'Station Shop',
    );
  });

  testWidgets('add details passes current edited state', (tester) async {
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

    await tester.enterText(amountField(), '55');
    await tester.enterText(merchantField(), 'Harbor');
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(1)).controller?.text,
      '55',
    );
    expect(find.widgetWithText(TextFormField, 'Harbor'), findsOneWidget);
    expect(repository.createdExpenses, isEmpty);
  });

  testWidgets('save stays on screen at common phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save');
    expect(saveButton, findsOneWidget);
    expect(tester.getBottomLeft(saveButton).dy, greaterThan(0));
  });

  testWidgets('narrow layout does not overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  testWidgets('arabic quick add keeps amount LTR and localized payment labels',
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

    final amount = tester.widget<TextField>(find.byType(TextField).first);
    expect(amount.textDirection, TextDirection.ltr);
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
