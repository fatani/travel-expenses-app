import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_currency_conversion_service.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/reports/data/trip_cash_balances_provider.dart';
import 'package:travel_expenses/features/reports/data/trip_report_provider.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_display.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/empty_expense_refund_repository.dart';
import '../../support/no_fifo_record_cash_expense_use_case.dart';
import '../../support/no_fifo_update_cash_expense_use_case.dart';
import '../../support/test_expense_repository.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-a05-02',
    name: 'A05-02 Trip',
    destination: 'Test',
    baseCurrency: 'SAR',
    destinationCurrency: 'SAR',
    homeCurrencySnapshot: 'SAR',
  );

  TripReportDisplay minimalReport() {
    return TripReportDisplay(
      summary: TripReportSummary(
        tripId: trip.id,
        tripName: trip.name,
        totalExpenseCount: 0,
        internationalExpenseCount: 0,
        domesticExpenseCount: 0,
        totalBilledByCurrency: const [],
        totalFeesByCurrency: const [],
        topCategory: null,
        topPaymentNetwork: null,
        topPaymentChannel: null,
        byCategory: const [],
        byTransactionCurrency: const [],
        byPaymentNetwork: const [],
        byPaymentChannel: const [],
        smartInsights: const [],
        reportingMoneyPreviews: const [],
        remainingCashValues: const [],
        pendingCardExpenseCount: 0,
        cashAcquisitionSummary: const [],
        paymentSourceSummary: const [],
      ),
      refundsByTransactionCurrency: const [],
    );
  }

  List<TripCashBalance> sampleBalances() {
    return [
      TripCashBalance(
        tripId: trip.id,
        currencyCode: 'SAR',
        balanceAmount: 500,
        updatedAt: DateTime.utc(2026, 6, 1),
      ),
    ];
  }

  ProviderContainer makeExpenseContainer({
    required _InMemoryExpenseRepository expenseRepo,
    int? cashBalanceFetchBudget,
  }) {
    var cashBalanceFetches = 0;
    return ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(expenseRepo),
        expenseRefundRepositoryProvider.overrideWithValue(
          EmptyExpenseRefundRepository(),
        ),
        cashWalletRepositoryProvider.overrideWithValue(
          _StubCashWalletRepository(),
        ),
        manualCurrencyConversionServiceProvider.overrideWithValue(
          ManualCurrencyConversionService(_NoOpManualRateRepository()),
        ),
        recordCashExpenseUseCaseProvider.overrideWith((ref) {
          return NoFifoRecordCashExpenseUseCase(
            expenseRepository: ref.watch(expenseRepositoryProvider),
            cashWalletRepository: ref.watch(cashWalletRepositoryProvider),
          );
        }),
        updateCashExpenseUseCaseProvider.overrideWith((ref) {
          return NoFifoUpdateCashExpenseUseCase(
            expenseRepository: ref.watch(expenseRepositoryProvider),
          );
        }),
        tripReportProvider(trip.id).overrideWith((ref) async {
          return minimalReport();
        }),
        tripCashBalancesProvider(trip.id).overrideWith((ref) async {
          cashBalanceFetches++;
          if (cashBalanceFetchBudget != null &&
              cashBalanceFetches > cashBalanceFetchBudget) {
            fail('tripCashBalancesProvider refetched unexpectedly');
          }
          return sampleBalances();
        }),
      ],
    );
  }

  group('A05-02 — cash snapshot provider invalidation', () {
    test('cash expense create invalidates tripCashBalancesProvider', () async {
      final expenseRepo = _InMemoryExpenseRepository();
      final container = makeExpenseContainer(
        expenseRepo: expenseRepo,
        cashBalanceFetchBudget: 2,
      );
      addTearDown(container.dispose);

      await container.read(tripCashBalancesProvider(trip.id).future);

      await container
          .read(expenseControllerProvider(trip.id).notifier)
          .createExpense(
            title: 'Snack',
            amount: 25,
            currencyCode: 'SAR',
            category: 'Food',
            spentAt: DateTime.utc(2026, 6, 1),
            paymentMethod: 'Cash',
            paymentChannel: 'Cash',
            tripHomeCurrency: 'SAR',
          );

      await container.read(tripCashBalancesProvider(trip.id).future);
      expect(expenseRepo.all, hasLength(1));
    });

    test(
      'card expense create does not invalidate tripCashBalancesProvider',
      () async {
        final expenseRepo = _InMemoryExpenseRepository();
        final container = makeExpenseContainer(
          expenseRepo: expenseRepo,
          cashBalanceFetchBudget: 1,
        );
        addTearDown(container.dispose);

        await container.read(tripCashBalancesProvider(trip.id).future);

        await container
            .read(expenseControllerProvider(trip.id).notifier)
            .createExpense(
              title: 'Hotel',
              amount: 400,
              currencyCode: 'SAR',
              category: 'Lodging',
              spentAt: DateTime.utc(2026, 6, 1),
              paymentMethod: 'Credit Card',
              paymentChannel: 'POS Purchase',
              tripHomeCurrency: 'SAR',
            );

        expect(expenseRepo.all, hasLength(1));
      },
    );

    test(
      'cash wallet refresh contract invalidates report and cash balances',
      () async {
        final tracker = _ProviderFetchTracker();
        final container = ProviderContainer(
          overrides: [
            tripReportProvider(trip.id).overrideWith((ref) async {
              tracker.reportFetches++;
              return minimalReport();
            }),
            tripCashBalancesProvider(trip.id).overrideWith((ref) async {
              tracker.cashBalanceFetches++;
              return sampleBalances();
            }),
          ],
        );
        addTearDown(container.dispose);

        await container.read(tripReportProvider(trip.id).future);
        await container.read(tripCashBalancesProvider(trip.id).future);
        expect(tracker.reportFetches, 1);
        expect(tracker.cashBalanceFetches, 1);

        invalidateTripCashReportSnapshots(container.invalidate, trip.id);

        await container.read(tripReportProvider(trip.id).future);
        await container.read(tripCashBalancesProvider(trip.id).future);
        expect(tracker.reportFetches, 2);
        expect(tracker.cashBalanceFetches, 2);
      },
    );
  });
}

class _ProviderFetchTracker {
  int reportFetches = 0;
  int cashBalanceFetches = 0;
}

class _InMemoryExpenseRepository extends TestExpenseRepository {
  final List<Expense> _expenses = [];

  List<Expense> get all => List.unmodifiable(_expenses);

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<Expense> createExpense(
    Expense expense, {
    DatabaseExecutor? txn,
  }) async {
    final withId = expense.id.isEmpty
        ? expense.copyWith(id: 'exp-${_expenses.length}')
        : expense;
    _expenses.add(withId);
    return withId;
  }

  @override
  Future<Expense?> getExpenseById(String expenseId) async {
    for (final expense in _expenses) {
      if (expense.id == expenseId) {
        return expense;
      }
    }
    return null;
  }
}

class _StubCashWalletRepository extends CashWalletRepository {
  _StubCashWalletRepository() : super(AppDatabase());

  @override
  Future<double?> getEffectiveCashRate({
    required String tripId,
    required String transactionCurrencyCode,
    required String homeCurrencyCode,
  }) async => 1;

  @override
  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
    DatabaseExecutor? txn,
  }) async => const CashExpenseDeductionResult(
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
