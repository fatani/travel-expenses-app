// Tests for cash expense conversion snapshot stability.
//
// Guarantees:
// 1. Cash expense created after an inflow captures the effective rate at
//    creation time (snapshot).
// 2. Adding a new inflow later does NOT change the stored snapshot of the
//    old expense.
// 3. A new expense created after the additional inflow uses the updated
//    weighted-average rate.
// 4. Editing an existing cash expense amount keeps the old stored rate and
//    only recalculates convertedHomeAmount.
// 5. Card expenses are unaffected by any cash pool logic.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_currency_conversion_service.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-snap',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  // ─── helpers ─────────────────────────────────────────────────────────────

  ProviderContainer makeContainer({
    required _FakeExpenseRepository expenseRepo,
    required _FakeCashWalletRepository walletRepo,
  }) {
    return ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(expenseRepo),
        cashWalletRepositoryProvider.overrideWithValue(walletRepo),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_NoOpManualRateRepository()),
        ),
      ],
    );
  }

  // ─── test 1 ──────────────────────────────────────────────────────────────

  test(
    'cash expense created after initial inflow captures rate A as snapshot',
    () async {
      final expenseRepo = _FakeExpenseRepository();
      // 50,000 THB ≈ 5,250 SAR  →  rate = 0.105
      final walletRepo = _FakeCashWalletRepository(
        ratesByKey: {'trip-snap|THB|SAR': 0.105},
      );
      final container = makeContainer(
        expenseRepo: expenseRepo,
        walletRepo: walletRepo,
      );
      addTearDown(container.dispose);

      await container
          .read(expenseControllerProvider(trip.id).notifier)
          .createExpense(
            title: 'Market',
            amount: 500,
            currencyCode: 'THB',
            category: 'Shopping',
            spentAt: DateTime(2026, 5, 1),
            paymentMethod: 'Cash',
            paymentChannel: 'Cash',
            tripHomeCurrency: 'SAR',
          );

      final saved = expenseRepo.all.single;
      expect(saved.conversionRate, closeTo(0.105, 0.000001));
      expect(saved.convertedHomeAmount, closeTo(52.5, 0.000001));
      expect(saved.homeCurrency, 'SAR');
    },
  );

  // ─── test 2 & 3 ──────────────────────────────────────────────────────────

  test(
    'old expense snapshot stays at rate A after new ATM inflow at rate B; '
    'new expense uses updated weighted-average rate',
    () async {
      final expenseRepo = _FakeExpenseRepository();

      // Initial state: 50,000 THB / 5,250 SAR  →  rate A = 0.105
      final walletRepo = _FakeCashWalletRepository(
        ratesByKey: {'trip-snap|THB|SAR': 0.105},
      );
      final container = makeContainer(
        expenseRepo: expenseRepo,
        walletRepo: walletRepo,
      );
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      // Create first expense at rate A.
      await controller.createExpense(
        title: 'Taxi',
        amount: 500,
        currencyCode: 'THB',
        category: 'Transport',
        spentAt: DateTime(2026, 5, 1),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      final first = expenseRepo.all.single;
      expect(first.conversionRate, closeTo(0.105, 0.000001));
      expect(first.convertedHomeAmount, closeTo(52.5, 0.000001));

      // Simulate new ATM inflow: 30,000 THB / 3,300 SAR  →  rate B = 0.11
      // Combined: 80,000 THB / 8,550 SAR  →  effective rate = 0.106875
      walletRepo.ratesByKey['trip-snap|THB|SAR'] = 8550.0 / 80000.0;

      // Create second expense – must use the updated rate.
      await controller.createExpense(
        title: 'Food',
        amount: 500,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 2),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      final expenses = expenseRepo.all;
      expect(expenses, hasLength(2));

      final oldExpense = expenses.firstWhere((e) => e.title == 'Taxi');
      final newExpense = expenses.firstWhere((e) => e.title == 'Food');

      // Old expense must be unchanged (rate A).
      expect(oldExpense.conversionRate, closeTo(0.105, 0.000001));
      expect(oldExpense.convertedHomeAmount, closeTo(52.5, 0.000001));

      // New expense uses updated effective rate.
      final expectedNewRate = 8550.0 / 80000.0;
      expect(newExpense.conversionRate, closeTo(expectedNewRate, 0.000001));
      expect(
        newExpense.convertedHomeAmount,
        closeTo(500 * expectedNewRate, 0.000001),
      );
    },
  );

  // ─── test 4 ──────────────────────────────────────────────────────────────

  test(
    'editing cash expense amount keeps stored rate; recalculates home amount',
    () async {
      final expenseRepo = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'cash-edit',
            tripId: trip.id,
            title: 'Market',
            amount: 500,
            currencyCode: 'THB',
            transactionAmount: 500,
            transactionCurrency: 'THB',
            originalAmount: 500,
            originalCurrency: 'THB',
            convertedHomeAmount: 52.5,
            homeCurrency: 'SAR',
            conversionRate: 0.105,
            spentAt: DateTime(2026, 5, 1),
            paymentMethod: 'Cash',
            paymentChannel: 'Cash',
            category: 'Shopping',
          ),
        ],
      );

      // ATM added later – new pool rate would be 0.11; must NOT affect edit.
      final walletRepo = _FakeCashWalletRepository(
        ratesByKey: {'trip-snap|THB|SAR': 0.11},
      );
      final container = makeContainer(
        expenseRepo: expenseRepo,
        walletRepo: walletRepo,
      );
      addTearDown(container.dispose);

      final existing = (await expenseRepo.getExpenseById('cash-edit'))!;
      await container
          .read(expenseControllerProvider(trip.id).notifier)
          .updateExpense(
            expense: existing,
            title: existing.title,
            amount: 800,
            currencyCode: 'THB',
            category: existing.category ?? 'Shopping',
            spentAt: existing.spentAt,
            paymentMethod: existing.paymentMethod,
            paymentNetwork: existing.paymentNetwork,
            paymentChannel: existing.paymentChannel,
            note: existing.note,
            source: existing.source,
            cardProfileId: existing.cardProfileId,
            tripHomeCurrency: 'SAR',
          );

      final saved = (await expenseRepo.getExpenseById('cash-edit'))!;
      // Rate must stay at original 0.105, NOT the current pool rate 0.11.
      expect(saved.conversionRate, closeTo(0.105, 0.000001));
      expect(saved.convertedHomeAmount, closeTo(84.0, 0.000001));
    },
  );

  // ─── test 5 ──────────────────────────────────────────────────────────────

  test(
    'card expense is unaffected by cash pool context; uses its own stored rate',
    () async {
      final expenseRepo = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'card-1',
            tripId: trip.id,
            title: 'Hotel',
            amount: 1500,
            currencyCode: 'THB',
            transactionAmount: 1500,
            transactionCurrency: 'THB',
            originalAmount: 1500,
            originalCurrency: 'THB',
            convertedHomeAmount: 157.5,
            homeCurrency: 'SAR',
            conversionRate: 0.105,
            spentAt: DateTime(2026, 5, 1),
            paymentMethod: 'Credit Card',
            paymentNetwork: 'Visa',
            paymentChannel: 'POS Purchase',
            category: 'Accommodation',
          ),
        ],
      );

      // Pool rate is different – must never touch card expense.
      final walletRepo = _FakeCashWalletRepository(
        ratesByKey: {'trip-snap|THB|SAR': 0.11},
      );
      final container = makeContainer(
        expenseRepo: expenseRepo,
        walletRepo: walletRepo,
      );
      addTearDown(container.dispose);

      final existing = (await expenseRepo.getExpenseById('card-1'))!;
      await container
          .read(expenseControllerProvider(trip.id).notifier)
          .updateExpense(
            expense: existing,
            title: existing.title,
            amount: 2000,
            currencyCode: 'THB',
            category: existing.category ?? 'Accommodation',
            spentAt: existing.spentAt,
            paymentMethod: existing.paymentMethod,
            paymentNetwork: existing.paymentNetwork,
            paymentChannel: existing.paymentChannel,
            tripHomeCurrency: 'SAR',
          );

      final saved = (await expenseRepo.getExpenseById('card-1'))!;
      // Card expense keeps its own stored rate 0.105, NOT the cash pool 0.11.
      expect(saved.conversionRate, closeTo(0.105, 0.000001));
      expect(saved.convertedHomeAmount, closeTo(210.0, 0.000001));
    },
  );

  test(
    'A/B/C cash expenses keep their own snapshots and never drift to newer rate',
    () async {
      final expenseRepo = _FakeExpenseRepository();
      final walletRepo = _FakeCashWalletRepository(
        ratesByKey: {'trip-snap|THB|SAR': 0.105},
      );
      final container = makeContainer(
        expenseRepo: expenseRepo,
        walletRepo: walletRepo,
      );
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      // A at 0.105
      await controller.createExpense(
        title: 'A',
        amount: 500,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 1),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      // B at 0.105
      await controller.createExpense(
        title: 'B',
        amount: 700,
        currencyCode: 'THB',
        category: 'Transport',
        spentAt: DateTime(2026, 5, 2),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      // New cash inflow raises current rate.
      walletRepo.ratesByKey['trip-snap|THB|SAR'] = 0.11;

      // C should snapshot 0.11 and stay there.
      await controller.createExpense(
        title: 'C',
        amount: 500,
        currencyCode: 'THB',
        category: 'Shopping',
        spentAt: DateTime(2026, 5, 3),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      final aBefore = expenseRepo.all.firstWhere((e) => e.title == 'A');
      final bBefore = expenseRepo.all.firstWhere((e) => e.title == 'B');
      final cBefore = expenseRepo.all.firstWhere((e) => e.title == 'C');

      expect(aBefore.conversionRate, closeTo(0.105, 0.000001));
      expect(bBefore.conversionRate, closeTo(0.105, 0.000001));
      expect(cBefore.conversionRate, closeTo(0.11, 0.000001));

      // Another inflow changes the current pool to 0.12.
      walletRepo.ratesByKey['trip-snap|THB|SAR'] = 0.12;

      // Existing snapshots must remain pinned.
      final aAfter = expenseRepo.all.firstWhere((e) => e.title == 'A');
      final bAfter = expenseRepo.all.firstWhere((e) => e.title == 'B');
      final cAfter = expenseRepo.all.firstWhere((e) => e.title == 'C');

      expect(aAfter.conversionRate, closeTo(0.105, 0.000001));
      expect(bAfter.conversionRate, closeTo(0.105, 0.000001));
      expect(cAfter.conversionRate, closeTo(0.11, 0.000001));
      expect(aAfter.convertedHomeAmount, closeTo(52.5, 0.000001));
      expect(bAfter.convertedHomeAmount, closeTo(73.5, 0.000001));
      expect(cAfter.convertedHomeAmount, closeTo(55.0, 0.000001));

      // Future expenses use the newest context.
      await controller.createExpense(
        title: 'Future',
        amount: 500,
        currencyCode: 'THB',
        category: 'Other',
        spentAt: DateTime(2026, 5, 4),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      final future = expenseRepo.all.firstWhere((e) => e.title == 'Future');
      expect(future.conversionRate, closeTo(0.12, 0.000001));
      expect(future.convertedHomeAmount, closeTo(60.0, 0.000001));
    },
  );
}

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;

  List<Expense> get all => List.unmodifiable(_expenses);

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async =>
      _expenses.where((e) => e.tripId == tripId).toList();

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Future<Expense> createExpense(Expense expense) async {
    final withId = expense.id.isEmpty
        ? expense.copyWith(id: 'generated-${_expenses.length}')
        : expense;
    _expenses.add(withId);
    return withId;
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) _expenses[index] = expense;
    return expense;
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository({Map<String, double>? ratesByKey})
      : ratesByKey = ratesByKey ?? {},
        super(AppDatabase());

  /// Key format: `tripId|transactionCurrency|homeCurrency`
  final Map<String, double> ratesByKey;

  @override
  Future<double?> getEffectiveCashRate({
    required String tripId,
    required String transactionCurrencyCode,
    required String homeCurrencyCode,
  }) async {
    final key =
        '$tripId|${transactionCurrencyCode.toUpperCase()}|${homeCurrencyCode.toUpperCase()}';
    return ratesByKey[key];
  }

  @override
  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
  }) async =>
      const CashExpenseDeductionResult(
        wasInsufficientBeforeDeduction: false,
        balanceAfterDeduction: 0,
      );

  @override
  Future<void> syncExpenseCashImpact({
    required Expense? previousExpense,
    required Expense nextExpense,
  }) async {}
}

class _NoOpManualRateRepository extends ManualExchangeRateRepository {
  _NoOpManualRateRepository() : super(AppDatabase());

  @override
  Future<ManualExchangeRate?> getLatestRate({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
  }) async => null;
}
