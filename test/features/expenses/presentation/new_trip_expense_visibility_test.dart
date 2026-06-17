// Regression coverage for the "new trip expense not appearing" bug.
//
// Root cause: a brand-new expense defaults to a Cash payment. In a freshly
// created trip with no cash recorded, the cash FIFO engine throws
// InsufficientCashException before any row is inserted. The controller converts
// that into an ExpenseCreateOutcome with createdExpenseId == null and
// cashBalanceInsufficient == true, but TripDetailsScreen previously showed
// "Expense added" regardless — so the expense silently vanished.
//
// These tests exercise the full controller → use case → repository → query
// chain against a real isolated database, plus a widget test proving the
// failure is now surfaced and nothing is inserted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/card_expense_completeness.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
// QuickAddExpenseSheet is part-of trip_details_screen.dart (imported below).
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late Trip trip;

  Trip freshTrip() => Trip.create(
        id: 'trip-new-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Bangkok',
        destination: 'Bangkok',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
        homeCurrencySnapshot: 'SAR',
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = createIsolatedAppDatabase(prefix: 'new_trip_expense');
    trip = await TripRepository(db).createTrip(freshTrip());
  });

  tearDown(() async => db.close());

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<List<dynamic>> loadExpenses(ProviderContainer c) =>
      c.read(expenseRepositoryProvider).getExpensesByTrip(trip.id);

  // ── Test 1 — card expense (with charged home amount) appears ───────────────
  test('1 — new trip + card expense with charged home amount appears',
      () async {
    final c = makeContainer();
    final outcome =
        await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
              title: 'Hotel',
              amount: 1500,
              currencyCode: 'THB',
              category: 'Accommodation',
              spentAt: DateTime(2026, 6, 1),
              paymentMethod: 'Credit Card',
              paymentNetwork: 'Visa',
              paymentChannel: 'POS Purchase',
              totalChargedAmount: 157.5,
              totalChargedCurrency: 'SAR',
              tripHomeCurrency: 'SAR',
            );

    expect(outcome.createdExpenseId, isNotNull);
    final expenses = await loadExpenses(c);
    expect(expenses, hasLength(1));
    expect(expenses.single.isReversed, isFalse);
    expect(expenses.single.tripId, trip.id);
  });

  // ── Test 2 — card expense without charged home amount appears + pending ────
  test('2 — new trip + card expense without charged amount appears as pending',
      () async {
    final c = makeContainer();
    final outcome =
        await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
              title: 'Dinner',
              amount: 800,
              currencyCode: 'THB',
              category: 'Food',
              spentAt: DateTime(2026, 6, 1),
              paymentMethod: 'Credit Card',
              paymentNetwork: 'Visa',
              paymentChannel: 'POS Purchase',
              tripHomeCurrency: 'SAR',
            );

    expect(outcome.createdExpenseId, isNotNull);
    final expenses = await loadExpenses(c);
    expect(expenses, hasLength(1));
    // Must remain in the list and be flagged pending (label only, not removed).
    expect(
      isPendingCardExpense(expense: expenses.single, tripHomeCurrency: 'SAR'),
      isTrue,
    );
  });

  // ── Test 3 — other expense appears ─────────────────────────────────────────
  test('3 — new trip + other expense appears', () async {
    final c = makeContainer();
    final outcome =
        await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
              title: 'Misc',
              amount: 120,
              currencyCode: 'THB',
              category: 'Other',
              spentAt: DateTime(2026, 6, 1),
              paymentMethod: 'Other',
              paymentChannel: 'Other',
              tripHomeCurrency: 'SAR',
            );

    expect(outcome.createdExpenseId, isNotNull);
    expect(await loadExpenses(c), hasLength(1));
  });

  // ── Test 4 — cash expense with available cash appears ──────────────────────
  test('4 — new trip + cash expense with available cash appears', () async {
    final c = makeContainer();
    // Seed cash via an ATM withdrawal so a THB lot exists for FIFO.
    await c.read(recordAtmWithdrawalUseCaseProvider).execute(
          tripId: trip.id,
          receivedAmount: 50000,
          receivedCurrency: 'THB',
        );

    final outcome =
        await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
              title: 'Street food',
              amount: 500,
              currencyCode: 'THB',
              category: 'Food',
              spentAt: DateTime(2026, 6, 2),
              paymentMethod: 'Cash',
              paymentChannel: 'Cash',
              tripHomeCurrency: 'SAR',
            );

    expect(outcome.createdExpenseId, isNotNull);
    expect(outcome.cashBalanceInsufficient, isFalse);
    final expenses = await loadExpenses(c);
    expect(expenses.where((e) => e.title == 'Street food'), hasLength(1));
  });

  // ── Test 5 — cash expense without cash fails visibly, inserts nothing ──────
  test('5 — new trip + cash expense without cash does not insert', () async {
    final c = makeContainer();
    final outcome =
        await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
              title: 'Coffee',
              amount: 50,
              currencyCode: 'THB',
              category: 'Food',
              spentAt: DateTime(2026, 6, 2),
              paymentMethod: 'Cash',
              paymentChannel: 'Cash',
              tripHomeCurrency: 'SAR',
            );

    expect(outcome.createdExpenseId, isNull);
    expect(outcome.cashBalanceInsufficient, isTrue);
    expect(await loadExpenses(c), isEmpty);
  });

  // ── Test 6 — successful create refreshes the controller state ──────────────
  test('6 — create refreshes the watched expense list state', () async {
    final c = makeContainer();
    // Initialise the provider (build) before mutating.
    await c.read(expenseControllerProvider(trip.id).future);

    await c.read(expenseControllerProvider(trip.id).notifier).createExpense(
          title: 'Souvenir',
          amount: 200,
          currencyCode: 'THB',
          category: 'Shopping',
          spentAt: DateTime(2026, 6, 3),
          paymentMethod: 'Other',
          paymentChannel: 'Other',
          tripHomeCurrency: 'SAR',
        );

    final state = c.read(expenseControllerProvider(trip.id)).value;
    expect(state, isNotNull);
    expect(state!.where((e) => e.title == 'Souvenir'), hasLength(1));
  });

  // ── Test 5 (UI) — failure is surfaced and the list stays empty ─────────────
  // Uses synchronous fakes (widget tests don't drive real sqflite I/O without
  // runAsync). The fake cash use case throws InsufficientCashException exactly
  // as the FIFO engine does for a cashless trip.
  testWidgets(
      '5 (UI) — quick-add cash expense in cashless trip shows error, not "added"',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final expenseRepo = _RecordingExpenseRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
          cashWalletRepositoryProvider.overrideWithValue(
            _NoOpCashWalletRepository(),
          ),
          cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
          recordCashExpenseUseCaseProvider.overrideWith(
            (ref) => _InsufficientCashUseCase(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripDetailsScreen(trip: trip),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Open quick add (defaults to Cash) and save a cash expense.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
    await tester.enterText(amountField, '50');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Sheet closed; clear insufficient-cash error shown, not a false success.
    expect(find.byType(QuickAddExpenseSheet), findsNothing);
    expect(
      find.text(
        'Not enough cash recorded to add this cash expense. '
        'Add cash to your wallet first, or pay by card.',
      ),
      findsOneWidget,
    );
    expect(find.text('Expense added'), findsNothing);

    // Nothing was persisted.
    expect(expenseRepo.created, isEmpty);
  });
}

// ── Fakes for the widget test ────────────────────────────────────────────────

class _RecordingExpenseRepository extends ExpenseRepository {
  _RecordingExpenseRepository() : super(AppDatabase());

  final List<Expense> created = <Expense>[];

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async => created;

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    created.add(expense);
    return expense;
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
  Future<double?> getEffectiveCashRate({
    required String tripId,
    required String transactionCurrencyCode,
    required String homeCurrencyCode,
  }) async =>
      null;
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}

/// Mirrors the FIFO engine's behaviour for a cashless trip: throws before any
/// write so the controller reports cashBalanceInsufficient with no inserted row.
class _InsufficientCashUseCase extends RecordCashExpenseUseCase {
  _InsufficientCashUseCase()
      : super(
          appDatabase: AppDatabase(),
          expenseRepository: ExpenseRepository(AppDatabase()),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
          fifoEngine: CashLotFifoEngine(CashLotRepository(AppDatabase())),
          lotRepository: CashLotRepository(AppDatabase()),
          consumptionRepository:
              CashLotConsumptionRepository(AppDatabase()),
        );

  @override
  Future<CashExpenseCreateResult> execute(Expense expense) async {
    throw const InsufficientCashException(
      required: 50,
      available: 0,
      currencyCode: 'THB',
    );
  }
}
