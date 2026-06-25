import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/reports/data/remaining_cash_from_lots.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/remaining_cash_value.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late ExpenseRefundRepository refundRepo;
  late RecordRefundUseCase recordRefund;
  late RecordCashExpenseUseCase recordCashExpense;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'ax01_net_trip_cost');
    tripRepo = TripRepository(db);
    expenseRepo = ExpenseRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    refundRepo = ExpenseRefundRepository(db);
    final fifoEngine = CashLotFifoEngine(lotRepo);
    recordCashExpense = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );
    recordRefund = RecordRefundUseCase(
      appDatabase: db,
      refundEngine: const RefundInheritanceEngine(),
      refundRepository: refundRepo,
      lotRepository: lotRepo,
      cashWalletRepository: walletRepo,
    );
    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-ax01',
        name: 'AX-01 Trip',
        destination: 'Test',
        baseCurrency: 'SAR',
        destinationCurrency: 'SAR',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  Future<TripReportSummary> buildReport() async {
    final expenses = await expenseRepo.getExpensesByTrip(trip.id);
    final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
    final summaries = await lotRepo.computeLotCurrencySummaries(
      tripId: trip.id,
      homeCurrencyCode: 'SAR',
    );
    final lotRemainingValues = summaries
        .where((s) => s.totalRemainingAmount > 0)
        .map(
          (s) => RemainingCashValue(
            currencyCode: s.currencyCode,
            balanceAmount: s.totalRemainingAmount,
            effectiveRate: s.totalHomeAmount / s.totalRemainingAmount,
            homeAmount: s.totalHomeAmount,
            homeCurrency: s.homeCurrencyCode,
          ),
        )
        .toList();
    final activeLots = await lotRepo.getActiveLotsForTrip(trip.id);
    final netTripCostRemainingValues = buildRemainingCashValuesFromLots(
      lots: activeLots,
      homeCurrencyCode: 'SAR',
      excludeSourceTypes: const {'cash_refund'},
    );
    return const TripReportCalculator().calculate(
      tripId: trip.id,
      tripName: trip.name,
      expenses: expenses,
      refunds: refunds,
      lotRemainingValues: lotRemainingValues,
      netTripCostRemainingValues: netTripCostRemainingValues,
      activeLots: activeLots,
    );
  }

  group('AX-01 — cash refund net trip cost', () {
    test('card expense 100 + cash refund 100 unspent → netTripCost is 0 not -100',
        () async {
      final cardExpense = await expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'Card purchase',
          amount: 100,
          currencyCode: 'SAR',
          transactionAmount: 100,
          transactionCurrency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
          conversionRate: 1,
          spentAt: DateTime.utc(2026, 6, 1),
          paymentMethod: 'Credit Card',
          paymentChannel: 'POS Purchase',
          category: 'Shopping',
        ),
      );

      await recordRefund.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: cardExpense.id,
        refundAmount: 100,
        refundCurrency: 'SAR',
        homeAmount: 100,
        homeCurrency: 'SAR',
        linkedExpense: cardExpense,
      );

      final report = await buildReport();

      expect(report.grossSpendingHomeAmount, closeTo(100, 1e-9));
      expect(report.refundHomeAmount, closeTo(100, 1e-9));
      expect(report.netSpendingHomeAmount, closeTo(0, 1e-9));
      expect(report.remainingCashValues, hasLength(1));
      expect(report.remainingCashValues.single.homeAmount, closeTo(100, 1e-9));
      expect(report.netTripCostHomeAmount, closeTo(0, 1e-9));
      expect(report.netTripCostHomeAmount, isNot(closeTo(-100, 1e-9)));
    });

    test('refund cash later spent keeps report consistent', () async {
      final cardExpense = await expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'Card purchase',
          amount: 100,
          currencyCode: 'SAR',
          transactionAmount: 100,
          transactionCurrency: 'SAR',
          convertedHomeAmount: 100,
          homeCurrency: 'SAR',
          conversionRate: 1,
          spentAt: DateTime.utc(2026, 6, 1),
          paymentMethod: 'Credit Card',
          paymentChannel: 'POS Purchase',
          category: 'Shopping',
        ),
      );

      await recordRefund.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: cardExpense.id,
        refundAmount: 100,
        refundCurrency: 'SAR',
        homeAmount: 100,
        homeCurrency: 'SAR',
        linkedExpense: cardExpense,
      );

      final beforeSpend = await buildReport();
      expect(beforeSpend.netTripCostHomeAmount, closeTo(0, 1e-9));

      await recordCashExpense.execute(
        Expense.create(
          tripId: trip.id,
          title: 'Spend refund cash',
          amount: 40,
          currencyCode: 'SAR',
          transactionAmount: 40,
          transactionCurrency: 'SAR',
          spentAt: DateTime.utc(2026, 6, 2),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
          category: 'Food',
        ),
      );

      final afterSpend = await buildReport();
      expect(afterSpend.grossSpendingHomeAmount, closeTo(140, 1e-9));
      expect(afterSpend.refundHomeAmount, closeTo(100, 1e-9));
      expect(afterSpend.netSpendingHomeAmount, closeTo(40, 1e-9));
      expect(afterSpend.remainingCashValues.single.balanceAmount,
          closeTo(60, 1e-9));
      // Remaining 60 SAR is still in a cash_refund lot (excluded from net-trip-cost
      // subtraction), so netTripCost equals netSpending.
      expect(afterSpend.netTripCostHomeAmount, closeTo(40, 1e-9));
    });

    test('calculator excludes cash_refund only from netTripCost subtraction', () {
      const calculator = TripReportCalculator();
      final expense = Expense.create(
        id: 'exp-1',
        tripId: 'trip-1',
        title: 'Card',
        amount: 100,
        currencyCode: 'SAR',
        transactionAmount: 100,
        transactionCurrency: 'SAR',
        convertedHomeAmount: 100,
        homeCurrency: 'SAR',
        spentAt: DateTime.utc(2026, 6, 1),
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS',
        category: 'Food',
      );

      final allRemaining = [
        const RemainingCashValue(
          currencyCode: 'SAR',
          balanceAmount: 100,
          effectiveRate: 1,
          homeAmount: 100,
          homeCurrency: 'SAR',
        ),
      ];

      final result = calculator.calculate(
        tripId: 'trip-1',
        tripName: 'Trip',
        expenses: [expense],
        refunds: [
          ExpenseRefund.create(
            id: 'ref-1',
            tripId: 'trip-1',
            expenseId: 'exp-1',
            amount: 100,
            currencyCode: 'SAR',
            homeAmount: 100,
            homeCurrency: 'SAR',
            destination: RefundDestination.cash,
          ),
        ],
        lotRemainingValues: allRemaining,
        netTripCostRemainingValues: const [],
      );

      expect(result.remainingCashValues.single.homeAmount, closeTo(100, 1e-9));
      expect(result.netTripCostHomeAmount, closeTo(0, 1e-9));
    });
  });
}
