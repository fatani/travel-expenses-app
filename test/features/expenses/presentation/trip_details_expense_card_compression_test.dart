import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-card-compression',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final sampleExpense = Expense.create(
    id: 'expense-1',
    tripId: trip.id,
    title: 'Street food',
    amount: 500,
    currencyCode: 'THB',
    transactionAmount: 500,
    transactionCurrency: 'THB',
    spentAt: DateTime(2026, 5, 16, 14, 30),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
    note: 'Spicy noodles near the market',
  );

  testWidgets('expense cards hide always-visible edit and delete icon buttons',
      (tester) async {
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

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Edit expense' &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.edit_outlined,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.delete_outline_rounded,
      ),
      findsNothing,
    );
  });

  testWidgets('tapping expense card opens expense form for editing', (tester) async {
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

    await tester.tap(find.text('Street food'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
  });

  testWidgets('delete remains available through expense card overflow menu',
      (tester) async {
  final repository = _FakeExpenseRepository(initialExpenses: [sampleExpense]);

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete expense?'), findsOneWidget);

    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Street food'), findsNothing);
    expect(find.text('Expense deleted'), findsOneWidget);
  });

  testWidgets('converted amount appears only when stored conversion data exists',
      (tester) async {
    final withConversion = Expense.create(
      id: 'with-conversion',
      tripId: trip.id,
      title: 'ATM cash',
      amount: 500,
      currencyCode: 'THB',
      transactionAmount: 500,
      transactionCurrency: 'THB',
      convertedHomeAmount: 52.5,
      homeCurrency: 'SAR',
      conversionRate: 0.105,
      spentAt: DateTime(2026, 5, 16),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Other',
    );
    final withoutConversion = Expense.create(
      id: 'without-conversion',
      tripId: trip.id,
      title: 'Local snack',
      amount: 80,
      currencyCode: 'THB',
      transactionAmount: 80,
      transactionCurrency: 'THB',
      spentAt: DateTime(2026, 5, 17),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(
              initialExpenses: [withConversion, withoutConversion],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ATM cash'), findsOneWidget);
    expect(find.text('Local snack'), findsOneWidget);
    expect(find.textContaining('52.5'), findsOneWidget);
    expect(find.textContaining('SAR'), findsWidgets);
    expect(find.textContaining('≈'), findsOneWidget);
    expect(find.textContaining('≈ 80'), findsNothing);
  });

  testWidgets('legacy stored conversion rate shows approximate amount not FX rate line',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'legacy-cash-rate-only',
          tripId: trip.id,
          title: 'Street food',
          amount: 500,
          currencyCode: 'THB',
          transactionAmount: 500,
          transactionCurrency: 'THB',
          originalAmount: 500,
          originalCurrency: 'THB',
          convertedHomeAmount: null,
          homeCurrency: 'SAR',
          conversionRate: 0.105,
          spentAt: DateTime(2026, 5, 16),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      ],
    );

    final cashWalletRepository = _FakeCashWalletRepository(
      balances: [
        TripCashBalance(
          tripId: trip.id,
          currencyCode: 'THB',
          balanceAmount: 10000,
          updatedAt: DateTime.utc(2026, 5, 16),
        ),
      ],
      transactions: [
        CashTransaction.create(
          id: 'atm-new-rate',
          tripId: trip.id,
          type: CashTransactionType.atmWithdrawal,
          amount: 30000,
          currencyCode: 'THB',
          homeCurrencyAmount: 3300,
          homeCurrencyCode: 'SAR',
        ),
      ],
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cashWalletRepositoryProvider.overrideWithValue(cashWalletRepository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('52.5'), findsOneWidget);
    expect(find.textContaining('1 THB ='), findsNothing);
    expect(find.textContaining('0.11'), findsNothing);
  });

  testWidgets('expense card does not show international fees line', (tester) async {
    final intlExpense = Expense.create(
      id: 'intl-fees',
      tripId: trip.id,
      title: 'Online purchase',
      amount: 10,
      currencyCode: 'THB',
      transactionAmount: 10,
      transactionCurrency: 'THB',
      billedAmount: 1.18,
      billedCurrency: 'SAR',
      feesAmount: 0.02,
      feesCurrency: 'SAR',
      totalChargedAmount: 1.20,
      totalChargedCurrency: 'SAR',
      isInternational: true,
      spentAt: DateTime(2026, 5, 16),
      paymentMethod: 'Credit Card',
      category: 'Other',
    );

    await tester.pumpWidget(
      _buildApp(
        child: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(initialExpenses: [intlExpense]),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Fees:'), findsNothing);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('THB'), findsOneWidget);
  });

  testWidgets('expense card truncates notes to one line', (tester) async {
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

    final noteFinder = find.text('Spicy noodles near the market');
    expect(noteFinder, findsOneWidget);

    final noteText = tester.widget<Text>(noteFinder);
    expect(noteText.maxLines, 1);
  });
}

Widget _buildApp({
  required Widget child,
  required List<Override> overrides,
  Locale locale = const Locale('en'),
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

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;
  final List<String> deletedExpenseIds = <String>[];

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<void> deleteExpense(String id) async {
    deletedExpenseIds.add(id);
    _expenses.removeWhere((expense) => expense.id == id);
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository({
    List<TripCashBalance>? balances,
    List<CashTransaction>? transactions,
  })  : _balances = balances ?? const <TripCashBalance>[],
        _transactions = transactions ?? const <CashTransaction>[],
        super(AppDatabase());

  final List<TripCashBalance> _balances;
  final List<CashTransaction> _transactions;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    return _balances.where((b) => b.tripId == tripId).toList();
  }

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async {
    final filtered = _transactions.where((t) => t.tripId == tripId).toList();
    if (filtered.length <= limit) {
      return filtered;
    }
    return filtered.take(limit).toList();
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
