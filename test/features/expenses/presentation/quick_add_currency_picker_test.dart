import 'package:sqflite/sqflite.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/quick_add_currency.dart';
import 'package:travel_expenses/features/expenses/presentation/quick_add_currency_picker.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/test_expense_repository.dart';

void main() {
  final multiCurrencyTrip = Trip.create(
    id: 'trip-mc',
    name: 'Multi Trip',
    destination: 'Europe',
    baseCurrency: 'EUR',
    destinationCurrency: 'CHF',
    homeCurrencySnapshot: 'SAR',
  );

  final recentExpenses = [
    Expense.create(
      id: 'exp-gbp',
      tripId: multiCurrencyTrip.id,
      title: 'Shop',
      amount: 10,
      currencyCode: 'GBP',
      spentAt: DateTime(2026, 5, 25),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Shopping',
    ),
    Expense.create(
      id: 'exp-jpy',
      tripId: multiCurrencyTrip.id,
      title: 'Train',
      amount: 20,
      currencyCode: 'JPY',
      spentAt: DateTime(2026, 5, 24),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Transport',
    ),
    Expense.create(
      id: 'exp-usd',
      tripId: multiCurrencyTrip.id,
      title: 'Cafe',
      amount: 5,
      currencyCode: 'USD',
      spentAt: DateTime(2026, 5, 23),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    ),
    Expense.create(
      id: 'exp-eur-dup',
      tripId: multiCurrencyTrip.id,
      title: 'Dup',
      amount: 1,
      currencyCode: 'EUR',
      spentAt: DateTime(2026, 5, 22),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Other',
    ),
  ];

  final pickerOptions = buildQuickAddCurrencyPickerOptions(
    multiCurrencyTrip,
    recentExpenses,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder currencyLabel() => find.byKey(const Key('quick_add_currency_label'));

  Future<void> tapCurrencyLabel(WidgetTester tester) async {
    final label = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.textContaining('▼'),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.ensureVisible(label);
    await tester.tap(label);
    await tester.pumpAndSettle();
  }

  Finder pickerTile(String code) =>
      find.byKey(ValueKey('quick_add_currency_option_$code'));

  Future<void> openQuickAdd(
    WidgetTester tester, {
    required Trip trip,
    List<Expense> expenses = const [],
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

  Finder amountField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  testWidgets('currency label is tappable and shows chevron', (tester) async {
    await tester.pumpWidget(_buildQuickAddSheetOnly(
      trip: multiCurrencyTrip,
      expenses: recentExpenses,
    ));
    await tester.pumpAndSettle();

    expect(currencyLabel(), findsOneWidget);
    expect(find.text('EUR ▼'), findsOneWidget);
  });

  testWidgets('currency picker opens with trip and recent currencies',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showQuickAddCurrencyPicker(
                      context: context,
                      options: pickerOptions,
                      selectedCode: 'EUR',
                    );
                  },
                  child: const Text('Open picker'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    expect(find.text('EUR'), findsWidgets);
    expect(find.text('CHF'), findsOneWidget);
    expect(find.text('SAR'), findsOneWidget);
    expect(find.text('GBP'), findsOneWidget);
    expect(find.text('JPY'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Other currency...'),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Other currency...'), findsOneWidget);
  });

  testWidgets('selecting a currency updates label and closes sheet',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, trip: multiCurrencyTrip, expenses: recentExpenses);

    await tester.enterText(amountField(), '1');
    await tapCurrencyLabel(tester);
    await tester.tap(pickerTile('CHF'));
    await tester.pumpAndSettle();

    expect(find.text('CHF ▼'), findsOneWidget);
    expect(find.text('EUR ▼'), findsNothing);
  });

  testWidgets('save uses selected currency', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FakeExpenseRepository(initialExpenses: recentExpenses);

    await openQuickAdd(
      tester,
      trip: multiCurrencyTrip,
      expenses: recentExpenses,
      repository: repository,
    );

    await tester.enterText(amountField(), '42');
    await tapCurrencyLabel(tester);
    await tester.tap(pickerTile('GBP'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    expect(repository.createdExpenses.single.currencyCode, 'GBP');
    expect(repository.createdExpenses.single.amount, 42);
  });

  testWidgets('add details receives selected currency', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await openQuickAdd(tester, trip: multiCurrencyTrip, expenses: recentExpenses);

    await tester.enterText(amountField(), '15');
    await tapCurrencyLabel(tester);
    await tester.tap(pickerTile('JPY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    final currencyField = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .firstWhere((field) => field.controller?.text == 'JPY');
    expect(currencyField.controller?.text, 'JPY');
  });

  testWidgets('other currency dialog validates three letters', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showQuickAddOtherCurrencyDialog(context),
                  child: const Text('Open dialog'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 3-letter currency code.'), findsOneWidget);

    await tester.enterText(dialogField, 'XY');
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 3-letter currency code.'), findsOneWidget);

    await tester.enterText(dialogField, 'cad');
    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('arabic quick add keeps currency code label LTR', (tester) async {
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
            body: QuickAddExpenseSheet(
              trip: multiCurrencyTrip,
              expenses: recentExpenses,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('EUR ▼'), findsOneWidget);
  });

  testWidgets('arabic currency picker is localized', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    showQuickAddCurrencyPicker(
                      context: context,
                      options: pickerOptions,
                      selectedCode: 'EUR',
                    );
                  },
                  child: const Text('فتح'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('quick_add_currency_option_other')),
      48,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('عملة أخرى...'), findsOneWidget);
    expect(find.text('CHF'), findsOneWidget);
  });
}

Widget _buildQuickAddSheetOnly({
  required Trip trip,
  List<Expense> expenses = const [],
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
  required List<Expense> expenses,
  _FakeExpenseRepository? repository,
}) {
  final repo =
      repository ?? _FakeExpenseRepository(initialExpenses: expenses);
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

class _FakeExpenseRepository extends TestExpenseRepository {
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
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
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
