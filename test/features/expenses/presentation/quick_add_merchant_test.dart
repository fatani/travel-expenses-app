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
import 'package:travel_expenses/features/expenses/presentation/quick_add_recent_merchants.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-merchant',
    name: 'Merchant Trip',
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

  group('deriveRecentMerchants', () {
    test('returns empty for no expenses', () {
      expect(deriveRecentMerchants(const []), isEmpty);
    });

    test('ignores empty merchant names', () {
      final merchants = deriveRecentMerchants([
        expense(id: '1', title: '  ', spentAt: baseTime),
        expense(id: '2', title: 'Cafe Nero', spentAt: baseTime.add(const Duration(hours: 1))),
      ]);
      expect(merchants, ['Cafe Nero']);
    });

    test('sorts by most recent spentAt first', () {
      final merchants = deriveRecentMerchants([
        expense(id: '1', title: 'Old Shop', spentAt: baseTime),
        expense(id: '2', title: 'New Shop', spentAt: baseTime.add(const Duration(days: 1))),
      ]);
      expect(merchants.first, 'New Shop');
      expect(merchants.last, 'Old Shop');
    });

    test('deduplicates case-insensitively keeping latest casing', () {
      final merchants = deriveRecentMerchants([
        expense(id: '1', title: 'starbucks', spentAt: baseTime),
        expense(id: '2', title: 'Starbucks', spentAt: baseTime.add(const Duration(hours: 2))),
        expense(id: '3', title: 'STARBUCKS', spentAt: baseTime.add(const Duration(hours: 1))),
      ]);
      expect(merchants, ['Starbucks']);
    });

    test('limits to maxCount', () {
      final merchants = deriveRecentMerchants(
        List.generate(
          10,
          (index) => expense(
            id: '$index',
            title: 'Shop $index',
            spentAt: baseTime.add(Duration(hours: index)),
          ),
        ),
        maxCount: 5,
      );
      expect(merchants, hasLength(5));
    });
  });

  group('resolveQuickAddExpenseTitle', () {
    test('uses merchant when provided', () {
      expect(
        resolveQuickAddExpenseTitle(merchantText: '  Cafe  ', category: 'Food'),
        'Cafe',
      );
    });

    test('falls back to category when merchant empty', () {
      expect(
        resolveQuickAddExpenseTitle(merchantText: '   ', category: 'Transport'),
        'Transport',
      );
    });
  });

  testWidgets('recent merchant chips appear from trip expenses only', (tester) async {
    final tripExpenses = [
      expense(id: '1', title: 'Airport Cafe', spentAt: baseTime),
      expense(id: '2', title: 'Metro Kiosk', spentAt: baseTime.add(const Duration(hours: 1))),
    ];

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: tripExpenses),
    );
    await tester.pumpAndSettle();

    expect(find.text('Airport Cafe'), findsOneWidget);
    expect(find.text('Metro Kiosk'), findsOneWidget);
  });

  testWidgets('tapping merchant chip fills merchant field', (tester) async {
    final tripExpenses = [
      expense(id: '1', title: 'Bakery Lane', spentAt: baseTime),
    ];

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: tripExpenses),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bakery Lane'));
    await tester.pumpAndSettle();

    final merchantField = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(merchantField.controller?.text, 'Bakery Lane');
  });

  testWidgets('save with amount only keeps merchant optional', (tester) async {
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
    await tester.enterText(amountField, '12');
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.createdExpenses, hasLength(1));
    expect(repository.createdExpenses.single.title, 'Food');
  });

  testWidgets('save uses merchant as expense title when entered', (tester) async {
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

    final sheet = find.byType(QuickAddExpenseSheet);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField).first),
      '25',
    );
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField).at(1)),
      'Corner Market',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, 'Save'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.createdExpenses.single.title, 'Corner Market');
  });

  testWidgets('add details passes merchant into expense form', (tester) async {
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

    final sheet = find.byType(QuickAddExpenseSheet);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField).first),
      '30',
    );
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField).at(1)),
      'Harbor Bistro',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Details'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Harbor Bistro'), findsOneWidget);
    expect(repository.createdExpenses, isEmpty);
  });

  testWidgets('arabic quick add shows merchant placeholder and keeps amount LTR',
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
    expect(find.text('المتجر'), findsOneWidget);
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
