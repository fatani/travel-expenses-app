import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/design_system/calm_snackbar.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_form_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final trip = Trip.create(
    id: 'trip-save-reliability',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Finder quickAddAmountField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  testWidgets('quick add double save creates only one expense', (tester) async {
    final repository = _DelayedCountingExpenseRepository();

    await tester.pumpWidget(_buildQuickAddHarness(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _selectQuickAddCardPayment(tester);
    await tester.enterText(quickAddAmountField(), '42');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.createCalls, 1);
    expect(repository.savedExpenses, hasLength(1));
  });

  testWidgets('keyboard done and save race creates only one expense', (tester) async {
    final repository = _DelayedCountingExpenseRepository();

    await tester.pumpWidget(_buildQuickAddHarness(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _selectQuickAddCardPayment(tester);
    await tester.enterText(quickAddAmountField(), '55');
    await tester.pump();

    final amountField = tester.widget<TextField>(quickAddAmountField());
    amountField.onSubmitted?.call('55');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.createCalls, 1);
    expect(repository.savedExpenses, hasLength(1));
  });

  testWidgets('quick add save failure keeps sheet open and input intact',
      (tester) async {
    final repository = _FailingCreateExpenseRepository();

    await tester.pumpWidget(_buildQuickAddHarness(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _selectQuickAddCardPayment(tester);
    await tester.enterText(quickAddAmountField(), '99');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(find.text('99'), findsOneWidget);
    expect(find.text("Couldn't save this expense. Please try again."), findsOneWidget);
    expect(repository.createCalls, 1);
  });

  testWidgets('invalid quick add save does not close sheet', (tester) async {
    final repository = _DelayedCountingExpenseRepository();

    await tester.pumpWidget(_buildQuickAddHarness(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(quickAddAmountField());
    amountField.onSubmitted?.call('');
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
    expect(repository.createCalls, 0);
  });

  testWidgets('add details double tap opens expense form only once', (tester) async {
    await tester.pumpWidget(_buildTripDetailsHarness(trip: trip));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final addDetails = find.text('Add Details');
    await tester.ensureVisible(addDetails);
    await tester.tap(addDetails, warnIfMissed: false);
    await tester.tap(addDetails, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.byType(QuickAddExpenseSheet), findsNothing);
  });

  testWidgets('expense form double save creates only one expense', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _DelayedCountingExpenseRepository();

    await tester.pumpWidget(
      _buildExpenseFormHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await _fillMinimalExpenseForm(tester, paymentChannel: 'POS Purchase');
    await tester.ensureVisible(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 1);
  });

  testWidgets('expense form save failure keeps form open with data intact',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FailingCreateExpenseRepository();

    await tester.pumpWidget(
      _buildExpenseFormHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await _fillMinimalExpenseForm(
      tester,
      title: 'Lunch',
      paymentChannel: 'POS Purchase',
    );
    await tester.ensureVisible(find.text('Add expense'));
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text("Couldn't save this expense. Please try again."), findsOneWidget);
  });

  testWidgets('trip edit double submit does not duplicate update calls',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _DelayedCountingTripRepository(trip: trip);

    await tester.pumpWidget(
      _buildTripEditHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
  });

  testWidgets('trip save failure keeps form input intact', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = _FailingTripUpdateRepository(trip: trip);

    await tester.pumpWidget(
      _buildTripEditHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Renamed Trip');
    await tester.pump();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.byType(TripFormScreen), findsOneWidget);
    expect(find.text('Renamed Trip'), findsOneWidget);
    expect(find.text("Couldn't save this trip. Please try again."), findsOneWidget);
  });

  testWidgets('cash wallet double submit creates one transaction', (tester) async {
    final repository = _DelayedCountingCashWalletRepository();

    await tester.pumpWidget(
      _buildCashWalletHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();

    expect(repository.addCalls, 1);
  });

  testWidgets('cash wallet save failure keeps sheet open', (tester) async {
    final repository = _FailingCashWalletRepository();

    await tester.pumpWidget(
      _buildCashWalletHarness(trip: trip, repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add Cash'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pump();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('50'), findsOneWidget);
    expect(find.text('50'), findsOneWidget);
    expect(find.text("Couldn't save this expense. Please try again."), findsOneWidget);
  });

  testWidgets('arabic quick add validation error has no overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(_EmptyExpenseRepository()),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: QuickAddExpenseSheet(trip: trip, expenses: const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final amountField = tester.widget<TextField>(quickAddAmountField());
    amountField.onSubmitted?.call('0');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
  });

  testWidgets('save failure uses CalmSnackBar not raw ScaffoldMessenger snackbar',
      (tester) async {
    await tester.pumpWidget(
      _buildQuickAddHarness(
        trip: trip,
        repository: _FailingCreateExpenseRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _selectQuickAddCardPayment(tester);
    await tester.enterText(quickAddAmountField(), '12');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.behavior, SnackBarBehavior.floating);
    expect(CalmSnackBar.isUndoSessionActive, isFalse);
  });
}

Future<void> _selectQuickAddCardPayment(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.text('Card'),
    ).first,
  );
  await tester.pump();
}

Future<void> _fillMinimalExpenseForm(
  WidgetTester tester, {
  String title = 'Snack',
  String paymentChannel = 'Cash',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), title);
  await tester.enterText(find.byType(TextFormField).at(1), '25');
  await tester.enterText(find.byType(TextFormField).at(2), 'THB');

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Food').last);
  await tester.pumpAndSettle();

  await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
  await tester.pumpAndSettle();
  await tester.tap(find.text(paymentChannel).last);
  await tester.pumpAndSettle();
}

Widget _buildQuickAddHarness({
  required Trip trip,
  required ExpenseRepository repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: QuickAddExpenseSheet(trip: trip, expenses: const [])),
    ),
  );
}

Widget _buildExpenseFormHarness({
  required Trip trip,
  required ExpenseRepository repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ExpenseFormScreen(trip: trip),
    ),
  );
}

Widget _buildTripDetailsHarness({
  required Trip trip,
  ExpenseRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(
        repository ?? _EmptyExpenseRepository(),
      ),
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

Widget _buildTripEditHarness({
  required Trip trip,
  required TripRepository repository,
}) {
  return ProviderScope(
    overrides: [
      tripRepositoryProvider.overrideWithValue(repository),
      expenseRepositoryProvider.overrideWithValue(_EmptyExpenseRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
      manualExchangeRateRepositoryProvider.overrideWithValue(
        _EmptyManualExchangeRateRepository(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripFormScreen(trip: trip),
    ),
  );
}

Widget _buildCashWalletHarness({
  required Trip trip,
  required CashWalletRepository repository,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(repository),
      expenseRepositoryProvider.overrideWithValue(_EmptyExpenseRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripCashWalletScreen(trip: trip),
    ),
  );
}

class _EmptyExpenseRepository extends TestExpenseRepository {
  _EmptyExpenseRepository({List<Expense>? initial})
      : _expenses = List<Expense>.from(initial ?? const []),
        super(AppDatabase());

  final List<Expense> _expenses;

  List<Expense> get savedExpenses => List.unmodifiable(_expenses);

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((e) => e.tripId == tripId).toList();
  }

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    _expenses.add(expense);
    return expense;
  }
}

class _DelayedCountingExpenseRepository extends _EmptyExpenseRepository {
  int createCalls = 0;

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    createCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return super.createExpense(expense, txn: txn);
  }
}

class _FailingCreateExpenseRepository extends _EmptyExpenseRepository {
  int createCalls = 0;

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    createCalls++;
    throw StateError('db unavailable');
  }
}

class _DelayedCountingTripRepository extends TripRepository {
  _DelayedCountingTripRepository({required this.trip}) : super(AppDatabase());

  final Trip trip;
  int updateCalls = 0;

  @override
  Future<List<Trip>> getTrips() async => [trip];

  @override
  Future<Trip?> getTripById(String id) async => trip;

  @override
  Future<Trip> updateTrip(Trip updatedTrip) async {
    updateCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return updatedTrip;
  }
}

class _FailingTripUpdateRepository extends _DelayedCountingTripRepository {
  _FailingTripUpdateRepository({required super.trip});

  @override
  Future<Trip> updateTrip(Trip updatedTrip) async {
    updateCalls++;
    throw StateError('db unavailable');
  }
}

class _DelayedCountingCashWalletRepository extends CashWalletRepository {
  int addCalls = 0;

  _DelayedCountingCashWalletRepository() : super(AppDatabase());

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

  @override
  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    addCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

}

class _FailingCashWalletRepository extends _DelayedCountingCashWalletRepository {
  @override
  Future<void> addCashTransaction({
    required String tripId,
    required CashTransactionType type,
    required double amount,
    required String currencyCode,
    double? homeCurrencyAmount,
    String? homeCurrencyCode,
    String? note,
    DateTime? createdAt,
  }) async {
    addCalls++;
    throw StateError('db unavailable');
  }
}

class _NoOpCashWalletRepository extends CashWalletRepository {
  _NoOpCashWalletRepository() : super(AppDatabase());

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

  @override
  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
    DatabaseExecutor? txn,
  }) async {
    if (txn != null) {
      return const CashExpenseDeductionResult(
        wasInsufficientBeforeDeduction: false,
        balanceAfterDeduction: 0,
      );
    }

    return super.recordCashExpenseDeduction(
      tripId: tripId,
      expenseId: expenseId,
      amount: amount,
      currencyCode: currencyCode,
      note: note,
    );
  }
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository([AppDatabase? appDatabase]) : super(appDatabase ?? AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}

class _EmptyManualExchangeRateRepository extends ManualExchangeRateRepository {
  _EmptyManualExchangeRateRepository() : super(AppDatabase());

  @override
  Future<List<ManualExchangeRate>> listLatestTripRates(String tripId) async =>
      const [];
}
