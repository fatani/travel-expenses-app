import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_currency_conversion_service.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_exception.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/no_fifo_update_cash_expense_use_case.dart';
import '../../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ax02',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final cardExpense = Expense.create(
    id: 'card-ax02',
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
  );

  final activeRefund = ExpenseRefund.create(
    id: 'refund-ax02',
    tripId: trip.id,
    expenseId: cardExpense.id,
    amount: 500,
    currencyCode: 'THB',
    homeAmount: 51.5,
    homeCurrency: 'SAR',
    destination: RefundDestination.card,
  );

  ProviderContainer buildContainer({
    required TestExpenseRepository repository,
    List<ExpenseRefund> refundsForExpense = const [],
  }) {
    return ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        expenseRefundRepositoryProvider.overrideWithValue(
          _FakeRefundRepository(refundsForExpense),
        ),
        updateCashExpenseUseCaseProvider.overrideWith(
          (ref) => NoFifoUpdateCashExpenseUseCase(
            expenseRepository: repository,
          ),
        ),
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
  }

  group('AX-02 — card→card edit active refund guard', () {
    test('card expense with active refund → card→card edit rejected', () async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [cardExpense],
      );
      final container = buildContainer(
        repository: repository,
        refundsForExpense: [activeRefund],
      );
      addTearDown(container.dispose);

      final controller =
          container.read(expenseControllerProvider(trip.id).notifier);
      final existing = (await repository.getExpenseById(cardExpense.id))!;

      await expectLater(
        controller.updateExpense(
          expense: existing,
          title: existing.title,
          amount: 2000,
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
        ),
        throwsA(
          isA<UpdateCashExpenseException>().having(
            (e) => e.reason,
            'reason',
            UpdateCashExpenseFailureReason.hasActiveRefunds,
          ),
        ),
      );

      final saved = (await repository.getExpenseById(cardExpense.id))!;
      expect(saved.transactionAmount, 1500);
    });

    test('card expense with no refunds → card→card edit succeeds', () async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [cardExpense],
      );
      final container = buildContainer(repository: repository);
      addTearDown(container.dispose);

      final controller =
          container.read(expenseControllerProvider(trip.id).notifier);
      final existing = (await repository.getExpenseById(cardExpense.id))!;

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

      final saved = (await repository.getExpenseById(cardExpense.id))!;
      expect(saved.transactionAmount, 2700);
    });
  });
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository({required List<Expense> initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async =>
      _expenses.where((e) => e.tripId == tripId && !e.isReversed).toList();

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
    return expense;
  }
}

class _FakeRefundRepository extends ExpenseRefundRepository {
  _FakeRefundRepository(this._refunds) : super(AppDatabase());

  final List<ExpenseRefund> _refunds;

  @override
  Future<List<ExpenseRefund>> getActiveRefundsByExpense(String expenseId) async {
    return _refunds
        .where((r) => r.expenseId == expenseId && !r.isReversed)
        .toList();
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository() : super(AppDatabase());
}

class _FakeManualExchangeRateRepository extends ManualExchangeRateRepository {
  _FakeManualExchangeRateRepository() : super(AppDatabase());

  @override
  Future<ManualExchangeRate?> getLatestRate({
    String? tripId,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    return null;
  }
}
