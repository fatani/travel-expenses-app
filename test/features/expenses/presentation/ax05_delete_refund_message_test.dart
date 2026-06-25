import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_exception.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_use_case.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/no_fifo_update_cash_expense_use_case.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ax05',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final coffeeExpense = Expense.create(
    id: 'expense-coffee',
    tripId: trip.id,
    title: 'Coffee',
    amount: 120,
    currencyCode: 'THB',
    transactionAmount: 120,
    transactionCurrency: 'THB',
    convertedHomeAmount: 12.5,
    homeCurrency: 'SAR',
    conversionRate: 0.104,
    spentAt: DateTime(2026, 5, 16),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  group('AX-05 — delete blocked message when expense has refunds', () {
    testWidgets('delete with active refund shows actionable message',
        (tester) async {
      final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

      await tester.pumpWidget(
        _buildTripDetails(
          trip: trip,
          repository: repository,
          updateCashExpenseUseCase: _RefundBlockedDeleteUseCase(
            expenseRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _confirmDelete(tester);
      await _waitForDeleteCommit(tester);

      expect(
        find.text(
          "Can't delete an expense that has refunds. Remove its refunds first.",
        ),
        findsOneWidget,
      );
      expect(
        find.text("Couldn't delete this expense. Try again."),
        findsNothing,
      );
      expect(repository.reversedExpenseIds, isEmpty);
    });

    testWidgets('delete without refund still succeeds', (tester) async {
      final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

      await tester.pumpWidget(
        _buildTripDetails(
          trip: trip,
          repository: repository,
          updateCashExpenseUseCase: NoFifoUpdateCashExpenseUseCase(
            expenseRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _confirmDelete(tester);
      expect(find.text('Expense deleted'), findsOneWidget);
      await _waitForDeleteCommit(tester);

      expect(repository.reversedExpenseIds, [coffeeExpense.id]);
    });

    testWidgets('other delete errors still use generic message', (tester) async {
      final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

      await tester.pumpWidget(
        _buildTripDetails(
          trip: trip,
          repository: repository,
          updateCashExpenseUseCase: _GenericFailureDeleteUseCase(
            expenseRepository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _confirmDelete(tester);
      await _waitForDeleteCommit(tester);

      expect(
        find.text("Couldn't delete this expense. Try again."),
        findsOneWidget,
      );
      expect(
        find.text(
          "Can't delete an expense that has refunds. Remove its refunds first.",
        ),
        findsNothing,
      );
    });
  });
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> _waitForDeleteCommit(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

Widget _buildTripDetails({
  required Trip trip,
  required ExpenseRepository repository,
  required UpdateCashExpenseUseCase updateCashExpenseUseCase,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
      updateCashExpenseUseCaseProvider.overrideWithValue(updateCashExpenseUseCase),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _RefundBlockedDeleteUseCase extends NoFifoUpdateCashExpenseUseCase {
  _RefundBlockedDeleteUseCase({required super.expenseRepository});

  @override
  Future<void> reverseAndDelete(String expenseId) async {
    throw const UpdateCashExpenseException(
      UpdateCashExpenseFailureReason.hasActiveRefunds,
    );
  }
}

class _GenericFailureDeleteUseCase extends NoFifoUpdateCashExpenseUseCase {
  _GenericFailureDeleteUseCase({required super.expenseRepository});

  @override
  Future<void> reverseAndDelete(String expenseId) async {
    throw StateError('db unavailable');
  }
}

class _TrackingExpenseRepository extends TestExpenseRepository {
  _TrackingExpenseRepository({required List<Expense> expenses})
      : _expenses = List<Expense>.from(expenses),
        super(AppDatabase());

  final List<Expense> _expenses;
  final List<String> reversedExpenseIds = [];

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses
        .where((e) => e.tripId == tripId && !e.isReversed)
        .toList();
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<Expense> updateExpense(Expense expense, {DatabaseExecutor? txn}) async {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      _expenses[index] = expense;
    }
    if (expense.isReversed) {
      reversedExpenseIds.add(expense.id);
    }
    return expense;
  }
}

class _NoOpCashWalletRepository extends CashWalletRepository {
  _NoOpCashWalletRepository() : super(AppDatabase());
}
