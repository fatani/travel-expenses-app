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
    id: 'trip-repeat',
    name: 'Repeat Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
  );

  final oldTimestamp = DateTime(2020, 1, 15, 10, 30);
  final lastExpense = Expense.create(
    id: 'exp-last',
    tripId: trip.id,
    title: 'Lunch at Cafe',
    amount: 25.5,
    currencyCode: 'USD',
    transactionAmount: 25.5,
    transactionCurrency: 'USD',
    spentAt: oldTimestamp,
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
    note: 'Private note',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> openQuickAdd(
    WidgetTester tester, {
    List<Expense>? expenses,
    _FakeExpenseRepository? repository,
  }) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenses: expenses,
        repository: repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
  }

  Finder amountField(WidgetTester tester) {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  Finder merchantField(WidgetTester tester) {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).at(1),
    );
  }

  testWidgets('normal quick add does not prefill amount from last expense',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: [lastExpense]);

    expect(
      tester.widget<TextField>(amountField(tester)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('normal quick add does not prefill merchant from last expense',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: [lastExpense]);

    expect(
      tester.widget<TextField>(merchantField(tester)).controller?.text,
      isEmpty,
    );
  });

  testWidgets('normal quick add defaults currency label to trip base currency',
      (tester) async {
    await openQuickAdd(tester, expenses: [lastExpense]);

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('CNY'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('USD'),
      ),
      findsNothing,
    );
  });

  testWidgets('repeat last is explicit via in-sheet action', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: [lastExpense]);

    expect(find.text('Repeat last expense'), findsOneWidget);
    expect(find.text('Same as last time'), findsNothing);

    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    expect(find.text('Same as last time'), findsOneWidget);
    expect(find.text('Repeat last expense'), findsNothing);
  });

  testWidgets('tapping repeat last applies amount merchant category payment currency',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: [lastExpense]);
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(amountField(tester)).controller?.text,
      '25.5',
    );
    expect(
      tester.widget<TextField>(merchantField(tester)).controller?.text,
      'Lunch at Cafe',
    );
    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('USD'),
      ),
      findsOneWidget,
    );
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
  });

  testWidgets('repeat last save uses current time not old expense time',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository(initialExpenses: [lastExpense]);
    final beforeSave = DateTime.now();

    await openQuickAdd(tester, repository: repository);
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    final saved = repository.createdExpenses.single;
    expect(saved.spentAt.isBefore(oldTimestamp), isFalse);
    expect(
      saved.spentAt.isAfter(beforeSave.subtract(const Duration(seconds: 2))),
      isTrue,
    );
    expect(saved.note, isNull);
  });

  testWidgets('repeated values remain editable before save', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository(initialExpenses: [lastExpense]);

    await openQuickAdd(tester, repository: repository);
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    await tester.enterText(amountField(tester), '99');
    await tester.enterText(merchantField(tester), 'Edited merchant');
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = repository.createdExpenses.single;
    expect(saved.amount, 99);
    expect(saved.title, 'Edited merchant');
    expect(saved.category, 'Transport');
  });

  testWidgets('add details receives edited state after repeat last',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: [lastExpense]);
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    await tester.enterText(amountField(tester), '77');
    await tester.enterText(merchantField(tester), 'Edited');
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Details'));
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    final formAmountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(formAmountField.controller?.text, '77');
    expect(find.text('Transport'), findsWidgets);
    expect(find.text('Edited'), findsWidgets);
  });

  testWidgets('manual category selection is not overwritten by amount heuristic',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, expenses: const []);

    await tester.enterText(amountField(tester), '5');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entertainment'));
    await tester.pumpAndSettle();
    await tester.enterText(amountField(tester), '500');
    await tester.pumpAndSettle();

    expect(find.text('Entertainment'), findsOneWidget);
  });

  testWidgets('payment default follows most recent trip expense', (tester) async {
    final older = Expense.create(
      id: 'exp-old',
      tripId: trip.id,
      title: 'Old',
      amount: 5,
      currencyCode: 'CNY',
      spentAt: DateTime(2026, 5, 10),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );
    final newer = Expense.create(
      id: 'exp-new',
      tripId: trip.id,
      title: 'New',
      amount: 12,
      currencyCode: 'CNY',
      spentAt: DateTime(2026, 5, 20),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Transport',
    );

    await openQuickAdd(tester, expenses: [older, newer]);

    final cashChip = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.widgetWithText(ChoiceChip, 'Cash'),
    );
    expect(tester.widget<ChoiceChip>(cashChip).selected, isTrue);
  });

  testWidgets('arabic repeat indicator is localized and compact', (tester) async {
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
            body: QuickAddExpenseSheet(trip: trip, expenses: [lastExpense]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('كرر آخر مصروف'));
    await tester.pumpAndSettle();

    expect(find.text('نفس آخر مصروف'), findsOneWidget);
    final amountFieldWidget = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountFieldWidget.textDirection, TextDirection.ltr);
  });

  testWidgets('repeat last does not convert currency amount', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository(initialExpenses: [lastExpense]);

    await openQuickAdd(tester, repository: repository);
    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = repository.createdExpenses.single;
    expect(saved.amount, 25.5);
    expect(saved.currencyCode, 'USD');
    expect(saved.conversionRate, isNull);
  });
}

Widget _buildTripDetailsApp({
  required Trip trip,
  List<Expense>? expenses,
  _FakeExpenseRepository? repository,
}) {
  final repo = repository ??
      _FakeExpenseRepository(initialExpenses: expenses ?? const []);
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
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

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const []),
        super(AppDatabase());

  final List<Expense> _expenses;
  final List<Expense> createdExpenses = <Expense>[];

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((e) => e.tripId == tripId).toList();
  }

  @override
  Future<Expense> createExpense(Expense expense) async {
    createdExpenses.add(expense);
    return expense;
  }
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
