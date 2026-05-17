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
    id: 'trip-1',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  test('updateExpense recalculates converted amount using existing card rate', () async {
    final repository = _FakeExpenseRepository(
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
          convertedHomeAmount: 154.5,
          homeCurrency: 'SAR',
          conversionRate: 0.103,
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Credit Card',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
          category: 'Accommodation',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(
            _FakeManualExchangeRateRepository(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('card-1'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 2700,
      currencyCode: 'THB',
      category: existing.category ?? 'Accommodation',
      spentAt: existing.spentAt,
      paymentMethod: existing.paymentMethod,
      paymentNetwork: existing.paymentNetwork,
      paymentChannel: existing.paymentChannel,
      note: existing.note,
      source: existing.source,
      cardProfileId: existing.cardProfileId,
      tripHomeCurrency: trip.homeCurrencySnapshot,
    );

    final saved = (await repository.getExpenseById('card-1'))!;
    expect(saved.transactionAmount, 2700);
    expect(saved.originalAmount, 2700);
    expect(saved.originalCurrency, 'THB');
    expect(saved.conversionRate, closeTo(0.103, 0.0000001));
    expect(saved.convertedHomeAmount, closeTo(278.1, 0.0000001));
    expect(saved.homeCurrency, 'SAR');
  });

  test('updateExpense preserves stored cash conversion rate when editing', () async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'cash-1',
            tripId: trip.id,
            title: 'Market',
            amount: 1500,
            currencyCode: 'THB',
            transactionAmount: 1500,
            transactionCurrency: 'THB',
            originalAmount: 1500,
            originalCurrency: 'THB',
            convertedHomeAmount: 154.5,
            homeCurrency: 'SAR',
            conversionRate: 0.103,
            spentAt: DateTime(2026, 5, 10),
            paymentMethod: 'Cash',
            category: 'Shopping',
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cashWalletRepositoryProvider.overrideWithValue(
            _FakeCashWalletRepository(),
          ),
          manualCurrencyConversionServiceProvider.overrideWithValue(
            ManualCurrencyConversionService(
              _FakeManualExchangeRateRepository(
                tripRates: {'${trip.id}|THB|SAR': 0.11},
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );
      final existing = (await repository.getExpenseById('cash-1'))!;

      await controller.updateExpense(
        expense: existing,
        title: existing.title,
        amount: 2700,
        currencyCode: 'THB',
        category: existing.category ?? 'Shopping',
        spentAt: existing.spentAt,
        paymentMethod: existing.paymentMethod,
        paymentNetwork: existing.paymentNetwork,
        paymentChannel: existing.paymentChannel,
        note: existing.note,
        source: existing.source,
        cardProfileId: existing.cardProfileId,
        tripHomeCurrency: trip.homeCurrencySnapshot,
      );

      final saved = (await repository.getExpenseById('cash-1'))!;
      expect(saved.transactionAmount, 2700);
      expect(saved.originalAmount, 2700);
      expect(saved.originalCurrency, 'THB');
      // Cash edits preserve the stored per-expense rate; 2700 × 0.103 = 278.1
      expect(saved.conversionRate, closeTo(0.103, 0.0000001));
      expect(saved.convertedHomeAmount, closeTo(278.1, 0.0000001));
      expect(saved.homeCurrency, 'SAR');
  });

  test('cash to card clears old cash snapshot fields', () async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'cash-to-card',
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
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Shopping',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(
            _FakeManualExchangeRateRepository(
              tripRates: {'${trip.id}|THB|SAR': 0.2},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('cash-to-card'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 500,
      currencyCode: 'THB',
      category: existing.category ?? 'Shopping',
      spentAt: existing.spentAt,
      paymentMethod: 'Credit Card',
      paymentNetwork: 'Visa',
      paymentChannel: 'POS Purchase',
      note: existing.note,
      source: existing.source,
      cardProfileId: existing.cardProfileId,
      tripHomeCurrency: trip.homeCurrencySnapshot,
    );

    final saved = (await repository.getExpenseById('cash-to-card'))!;
    expect(saved.originalAmount, isNull);
    expect(saved.originalCurrency, isNull);
    expect(saved.conversionRate, isNull);
    expect(saved.convertedHomeAmount, isNull);
    expect(saved.homeCurrency, isNull);
  });

  test('card with charged home amount derives card FX snapshot', () async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'card-fx',
          tripId: trip.id,
          title: 'Hotel',
          amount: 1350,
          currencyCode: 'THB',
          transactionAmount: 1350,
          transactionCurrency: 'THB',
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Credit Card',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
          category: 'Accommodation',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_FakeManualExchangeRateRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('card-fx'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 1350,
      currencyCode: 'THB',
      transactionAmount: 1350,
      transactionCurrency: 'THB',
      totalChargedAmount: 152,
      totalChargedCurrency: 'SAR',
      category: existing.category ?? 'Accommodation',
      spentAt: existing.spentAt,
      paymentMethod: 'Credit Card',
      paymentNetwork: 'Visa',
      paymentChannel: 'POS Purchase',
      tripHomeCurrency: 'SAR',
    );

    final saved = (await repository.getExpenseById('card-fx'))!;
    expect(saved.originalAmount, closeTo(1350, 0.0000001));
    expect(saved.originalCurrency, 'THB');
    expect(saved.convertedHomeAmount, closeTo(152, 0.0000001));
    expect(saved.homeCurrency, 'SAR');
    expect(saved.conversionRate, closeTo(152 / 1350, 0.0000001));
  });

  test('card to cash creates a new cash snapshot from current cash pool rate', () async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'card-to-cash',
          tripId: trip.id,
          title: 'Transfer',
          amount: 500,
          currencyCode: 'THB',
          transactionAmount: 500,
          transactionCurrency: 'THB',
          originalAmount: 500,
          originalCurrency: 'THB',
          convertedHomeAmount: 56,
          homeCurrency: 'SAR',
          conversionRate: 0.112,
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Credit Card',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
          category: 'Other',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(effectiveRate: 0.105),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_FakeManualExchangeRateRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('card-to-cash'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 500,
      currencyCode: 'THB',
      category: existing.category ?? 'Other',
      spentAt: existing.spentAt,
      paymentMethod: 'Cash',
      paymentNetwork: null,
      paymentChannel: 'Cash',
      tripHomeCurrency: 'SAR',
    );

    final saved = (await repository.getExpenseById('card-to-cash'))!;
    expect(saved.originalAmount, closeTo(500, 0.0000001));
    expect(saved.originalCurrency, 'THB');
    expect(saved.conversionRate, closeTo(0.105, 0.0000001));
    expect(saved.convertedHomeAmount, closeTo(52.5, 0.0000001));
    expect(saved.homeCurrency, 'SAR');
  });

  test('card to card updates FX snapshot when charged amount changes', () async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'card-edit-charged',
          tripId: trip.id,
          title: 'Hotel',
          amount: 1350,
          currencyCode: 'THB',
          transactionAmount: 1350,
          transactionCurrency: 'THB',
          originalAmount: 1350,
          originalCurrency: 'THB',
          convertedHomeAmount: 152,
          homeCurrency: 'SAR',
          conversionRate: 152 / 1350,
          totalChargedAmount: 152,
          totalChargedCurrency: 'SAR',
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Credit Card',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
          category: 'Accommodation',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_FakeManualExchangeRateRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('card-edit-charged'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 1350,
      currencyCode: 'THB',
      transactionAmount: 1350,
      transactionCurrency: 'THB',
      totalChargedAmount: 160,
      totalChargedCurrency: 'SAR',
      category: existing.category ?? 'Accommodation',
      spentAt: existing.spentAt,
      paymentMethod: existing.paymentMethod,
      paymentNetwork: existing.paymentNetwork,
      paymentChannel: existing.paymentChannel,
      tripHomeCurrency: 'SAR',
    );

    final saved = (await repository.getExpenseById('card-edit-charged'))!;
    expect(saved.convertedHomeAmount, closeTo(160, 0.0000001));
    expect(saved.conversionRate, closeTo(160 / 1350, 0.0000001));
    expect(saved.homeCurrency, 'SAR');
  });

  test('card to card clearing charged amount clears FX snapshot', () async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'card-clear-charged',
          tripId: trip.id,
          title: 'Hotel',
          amount: 1350,
          currencyCode: 'THB',
          transactionAmount: 1350,
          transactionCurrency: 'THB',
          originalAmount: 1350,
          originalCurrency: 'THB',
          convertedHomeAmount: 152,
          homeCurrency: 'SAR',
          conversionRate: 152 / 1350,
          totalChargedAmount: 152,
          totalChargedCurrency: 'SAR',
          spentAt: DateTime(2026, 5, 10),
          paymentMethod: 'Credit Card',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
          category: 'Accommodation',
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_FakeManualExchangeRateRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      expenseControllerProvider(trip.id).notifier,
    );
    final existing = (await repository.getExpenseById('card-clear-charged'))!;

    await controller.updateExpense(
      expense: existing,
      title: existing.title,
      amount: 1350,
      currencyCode: 'THB',
      transactionAmount: 1350,
      transactionCurrency: 'THB',
      totalChargedAmount: null,
      totalChargedCurrency: null,
      category: existing.category ?? 'Accommodation',
      spentAt: existing.spentAt,
      paymentMethod: existing.paymentMethod,
      paymentNetwork: existing.paymentNetwork,
      paymentChannel: existing.paymentChannel,
      tripHomeCurrency: 'SAR',
    );

    final saved = (await repository.getExpenseById('card-clear-charged'))!;
    expect(saved.originalAmount, isNull);
    expect(saved.originalCurrency, isNull);
    expect(saved.convertedHomeAmount, isNull);
    expect(saved.homeCurrency, isNull);
    expect(saved.conversionRate, isNull);
  });
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

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index >= 0) {
      _expenses[index] = expense;
    }
    return expense;
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository({this.effectiveRate}) : super(AppDatabase());

  final double? effectiveRate;

  @override
  Future<double?> getEffectiveCashRate({
    required String tripId,
    required String transactionCurrencyCode,
    required String homeCurrencyCode,
  }) async {
    return effectiveRate;
  }

  @override
  Future<void> syncExpenseCashImpact({
    required Expense? previousExpense,
    required Expense nextExpense,
  }) async {}
}

class _FakeManualExchangeRateRepository extends ManualExchangeRateRepository {
  _FakeManualExchangeRateRepository({
    Map<String, double>? tripRates,
    Map<String, double>? globalRates,
  }) : _tripRates = tripRates ?? const {},
       _globalRates = globalRates ?? const {},
       super(AppDatabase());

  final Map<String, double> _tripRates;
  final Map<String, double> _globalRates;

  @override
  Future<ManualExchangeRate?> getLatestRate({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final normalizedFrom = fromCurrency.trim().toUpperCase();
    final normalizedTo = toCurrency.trim().toUpperCase();
    final tripKey = '${tripId ?? ''}|$normalizedFrom|$normalizedTo';
    final globalKey = '$normalizedFrom|$normalizedTo';

    final tripRate = _tripRates[tripKey];
    if (tripRate != null) {
      return ManualExchangeRate.create(
        tripId: tripId,
        fromCurrency: normalizedFrom,
        toCurrency: normalizedTo,
        rate: tripRate,
      );
    }

    final globalRate = _globalRates[globalKey];
    if (globalRate != null) {
      return ManualExchangeRate.create(
        fromCurrency: normalizedFrom,
        toCurrency: normalizedTo,
        rate: globalRate,
      );
    }

    return null;
  }
}