import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/sms_parser/presentation/sms_expense_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-hierarchy',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
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

  testWidgets('hides Add Expense FAB when expense list is empty', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Add Expense'), findsNothing);
    expect(find.text('Add your first expense now'), findsOneWidget);
  });

  testWidgets('shows Add Expense FAB when at least one expense exists', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Add Expense'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.text('Add Expense'),
      ),
      findsNothing,
    );
  });

  testWidgets('Add Expense FAB opens fresh quick add, not repeat mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(find.text('Ready to add a similar expense'), findsNothing);
  });

  testWidgets('Add Expense FAB is not Repeat last expense', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Add Expense'), findsOneWidget);
    expect(find.byTooltip('Repeat last expense'), findsNothing);
    expect(find.text('Repeat last expense'), findsOneWidget);
  });

  testWidgets('primary button stays Add Expense when expenses exist', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add Expense'), findsOneWidget);
    expect(find.text('Repeat last expense'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Add Expense'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.add_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Repeat last expense'),
          matching: find.byType(OutlinedButton),
        ),
        matching: find.byIcon(Icons.refresh_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Add Expense opens fresh quick add, not repeat mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Expense'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(find.text('Ready to add a similar expense'), findsNothing);
  });

  testWidgets('Repeat last expense opens quick add in repeat mode', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repeat last expense'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(find.text('Ready to add a similar expense'), findsOneWidget);
  });

  testWidgets('hides cash wallet outline button when tracking not started',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cash tracking hasn’t started'), findsNothing);
    expect(find.text('Add cash balance'), findsNothing);
  });

  testWidgets('shows cash wallet outline button when tracking is active',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
        cashWalletRepository: _FakeCashWalletRepository(
          balances: [
            TripCashBalance(
              tripId: trip.id,
              currencyCode: 'CNY',
              balanceAmount: 500,
              updatedAt: DateTime(2026, 5, 16),
            ),
          ],
          transactions: [
            CashTransaction.create(
              id: 'cash-tx-1',
              tripId: trip.id,
              type: CashTransactionType.initialCash,
              amount: 500,
              currencyCode: 'CNY',
              createdAt: DateTime(2026, 5, 16),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
    expect(find.text('Cash tracking hasn’t started'), findsNothing);
  });

  testWidgets('shows cash wallet CTA when balance row is zero', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
        cashWalletRepository: _FakeCashWalletRepository(
          balances: [
            TripCashBalance(
              tripId: trip.id,
              currencyCode: 'CNY',
              balanceAmount: 0,
              updatedAt: DateTime(2026, 5, 16),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
  });

  testWidgets('shows cash wallet CTA when balance row is negative',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
        cashWalletRepository: _FakeCashWalletRepository(
          balances: [
            TripCashBalance(
              tripId: trip.id,
              currencyCode: 'CNY',
              balanceAmount: -120,
              updatedAt: DateTime(2026, 5, 16),
            ),
          ],
          transactions: [
            CashTransaction.create(
              id: 'cash-tx-deduction',
              tripId: trip.id,
              type: CashTransactionType.cashExpenseDeduction,
              amount: 120,
              currencyCode: 'CNY',
              createdAt: DateTime(2026, 5, 16),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
  });

  testWidgets(
      'shows cash wallet CTA with deduction-only history when balance row exists',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
        cashWalletRepository: _FakeCashWalletRepository(
          balances: [
            TripCashBalance(
              tripId: trip.id,
              currencyCode: 'CNY',
              balanceAmount: -50,
              updatedAt: DateTime(2026, 5, 16),
            ),
          ],
          transactions: [
            CashTransaction.create(
              id: 'cash-tx-deduction-only',
              tripId: trip.id,
              type: CashTransactionType.cashExpenseDeduction,
              amount: 50,
              currencyCode: 'CNY',
              createdAt: DateTime(2026, 5, 16),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('remaining'), findsOneWidget);
    expect(find.text('Cash Wallet'), findsOneWidget);
  });

  testWidgets('shows overflow menu in app bar with reports and export actions',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsNothing);
    expect(find.byIcon(Icons.file_download_outlined), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byIcon(Icons.edit_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Trip report'), findsOneWidget);
    expect(find.text('Add via Bank SMS'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });

  testWidgets('hides inline SMS button in active expense-list state', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add via Bank SMS'), findsNothing);
  });

  testWidgets('overflow menu SMS import opens SMS expense screen', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(
          initialExpenses: [sampleExpense],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    final smsMenuItem = find.descendant(
      of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      matching: find.text('Add via Bank SMS'),
    );
    expect(smsMenuItem, findsOneWidget);

    await tester.tap(smsMenuItem);
    await tester.pumpAndSettle();

    expect(find.byType(SmsExpenseScreen), findsOneWidget);
  });

  testWidgets('empty state keeps inline SMS button for discoverability', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add your first expense now'), findsOneWidget);
    expect(find.text('Add via Bank SMS'), findsOneWidget);
  });

  testWidgets('overflow menu is present on empty trip details', (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        repository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Trip report'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
        matching: find.text('Add via Bank SMS'),
      ),
      findsNothing,
    );
    expect(find.text('Export CSV'), findsOneWidget);
    expect(find.text('Export PDF'), findsOneWidget);
  });
}

Widget _buildTripDetailsApp({
  required Trip trip,
  required _FakeExpenseRepository repository,
  CashWalletRepository? cashWalletRepository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cashWalletRepositoryProvider.overrideWithValue(
        cashWalletRepository ?? _EmptyCashWalletRepository(),
      ),
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

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      const [];
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
    return _balances.where((balance) => balance.tripId == tripId).toList();
  }

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async {
    final filtered =
        _transactions.where((transaction) => transaction.tripId == tripId);
    if (filtered.length <= limit) {
      return filtered.toList();
    }
    return filtered.take(limit).toList();
  }
}
