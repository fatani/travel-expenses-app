import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-integrity',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
    homeCurrencySnapshot: 'CNY',
  );

  final mismatchedExpense = Expense.create(
    id: 'expense-sar',
    tripId: trip.id,
    title: 'Coffee',
    amount: 12.5,
    currencyCode: 'SAR',
    spentAt: DateTime(2026, 4, 12, 10, 30),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  testWidgets(
    'invalid charged home amount shows validation error on save',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: ExpenseFormScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Lunch');
      await tester.enterText(find.byType(TextFormField).at(1), '25');
      await tester.enterText(find.byType(TextFormField).at(2), 'CNY');

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS Purchase').last);
      await tester.pumpAndSettle();

      expect(find.text('Charged amount in CNY'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(3), 'not-a-number');
      await tester.pump();

      await tester.ensureVisible(find.text('Add expense'));
      await tester.tap(find.text('Add expense'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Enter a valid number.'), findsOneWidget);
      expect(repository.createdExpenses, isEmpty);
      expect(find.byType(ExpenseFormScreen), findsOneWidget);
    },
  );

  testWidgets(
    'currency mismatch warning appears when editing expense with foreign currency',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repository = _RecordingExpenseRepository(
        initialExpenses: [mismatchedExpense],
      );

      await tester.pumpWidget(
        _buildApp(
          child: ExpenseFormScreen(trip: trip, expense: mismatchedExpense),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save changes'));
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(
        find.text('Currency differs from trip base currency'),
        findsOneWidget,
      );
      expect(repository.updatedExpenses, isEmpty);

      await tester.tap(find.text('Keep as-is'));
      await tester.pumpAndSettle();

      expect(repository.updatedExpenses, hasLength(1));
      expect(repository.updatedExpenses.single.currencyCode, 'SAR');
    },
  );

  testWidgets('expense form section labels use localization', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: ExpenseFormScreen(trip: trip),
        overrides: const [],
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basic expense'), findsOneWidget);
    expect(find.text('Classification'), findsOneWidget);
    expect(find.text('Date & Notes'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);
  });

  testWidgets('expense form section labels render in Arabic', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        child: ExpenseFormScreen(trip: trip),
        overrides: const [],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('البيانات الأساسية'), findsOneWidget);
    expect(find.text('التصنيف'), findsOneWidget);
    expect(find.text('التاريخ والملاحظات'), findsOneWidget);
    expect(find.text('إنشاء المصروف'), findsOneWidget);
  });

  testWidgets(
    'expense form time field does not show required asterisk',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: ExpenseFormScreen(trip: trip),
          overrides: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expense time'), findsOneWidget);
      expect(find.text('Expense time *'), findsNothing);
    },
  );
}

Widget _buildApp({
  required Widget child,
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

class _RecordingExpenseRepository extends TestExpenseRepository {
  _RecordingExpenseRepository({List<Expense>? initialExpenses})
    : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
      super(AppDatabase());

  final List<Expense> _expenses;
  final List<Expense> createdExpenses = <Expense>[];
  final List<Expense> updatedExpenses = <Expense>[];

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    createdExpenses.add(expense);
    _expenses.add(expense);
    return expense;
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    updatedExpenses.add(expense);
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
    }
    return expense;
  }
}
