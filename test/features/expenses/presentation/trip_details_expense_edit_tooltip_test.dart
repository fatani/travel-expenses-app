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
    id: 'trip-tooltip',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
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

  testWidgets('expense edit button uses Edit expense tooltip in English',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Lunch'), 200);
    await tester.pumpAndSettle();

    final expenseEditButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Edit expense',
    );
    expect(expenseEditButton, findsOneWidget);
    expect(find.text('Edit trip'), findsNothing);

    final iconButton = tester.widget<IconButton>(expenseEditButton);
    expect(iconButton.tooltip, 'Edit expense');
  });

  testWidgets('expense edit button uses Arabic expense tooltip not trip tooltip',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(initialExpenses: [sampleExpense]),
          ),
        ],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Lunch'), 200);
    await tester.pumpAndSettle();

    final expenseEditButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'تعديل المصروف',
    );
    expect(expenseEditButton, findsOneWidget);
    expect(find.text('تعديل الرحلة'), findsNothing);

    final iconButton = tester.widget<IconButton>(expenseEditButton);
    expect(iconButton.tooltip, 'تعديل المصروف');
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
