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
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

/// Stage 1.2.6 — end-to-end Quick Capture integration coverage.
void main() {
  final trip = Trip.create(
    id: 'trip-integration',
    name: 'Integration Trip',
    destination: 'Test',
    baseCurrency: 'USD',
  );

  final lastExpense = Expense.create(
    id: 'exp-last',
    tripId: trip.id,
    title: 'Corner Cafe',
    amount: 18,
    currencyCode: 'USD',
    spentAt: DateTime(2026, 5, 20, 14),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder sheetAmountField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  Future<void> openViaFab(
    WidgetTester tester, {
    List<Expense>? expenses,
    _FakeExpenseRepository? repository,
  }) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: repository ??
            _FakeExpenseRepository(initialExpenses: expenses ?? const []),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('FAB opens quick add with amount field focused', (tester) async {
    await openViaFab(tester);

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    final amount = tester.widget<TextField>(sheetAmountField());
    expect(amount.focusNode?.hasFocus, isTrue);
  });

  testWidgets('quick add never shows last-amount hint or duplicate add details',
      (tester) async {
    await openViaFab(tester, expenses: [lastExpense]);

    expect(find.textContaining('Last:'), findsNothing);
    expect(find.textContaining('last:'), findsNothing);
    expect(find.text('Add Details'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
  });

  testWidgets('arabic quick add sheet smoke: localized controls no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

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

    expect(tester.takeException(), isNull);
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.text('إضافة تفاصيل'), findsOneWidget);
    expect(find.text('المتجر'), findsOneWidget);
    expect(find.text('كرر آخر مصروف'), findsOneWidget);

    final amount = tester.widget<TextField>(find.byType(TextField).first);
    expect(amount.textDirection, TextDirection.ltr);

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('USD'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('360x640 layout keeps save reachable without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildQuickAddApp(trip: trip, expenses: const []),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final save = find.widgetWithText(FilledButton, 'Save');
    expect(save, findsOneWidget);
    expect(tester.getBottomLeft(save).dy, greaterThan(0));
  });

  testWidgets('late preference load does not overwrite manual category',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'quick_add_last_category_${trip.id}': 'Accommodation',
    });

    await tester.pumpWidget(_buildQuickAddApp(trip: trip, expenses: const []));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('Entertainment'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(find.text('Entertainment'), findsOneWidget);
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
