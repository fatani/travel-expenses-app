// Financial Core Final Audit v1.0 — integration audit scenarios.
//
// Verifies end-to-end correctness of:
//   Cash Lots, FIFO Consumption, ATM Cost Basis, Currency Exchange Cost
//   Transfer, Refund Lot Inheritance, Cash Expense Edit (Reverse + Recreate),
//   Cash Expense Delete (Reverse + Mark Reversed), Net Trip Cost Reporting.
//
// Each scenario inspects the raw tables (expenses, cash_lots,
// cash_lot_consumptions, cash_transactions, currency_exchanges,
// expense_refunds, trip_cash_balances) plus the TripReportCalculator output.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_use_case.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/reports/domain/remaining_cash_value.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late CurrencyExchangeRepository exchangeRepo;
  late ExpenseRefundRepository refundRepo;
  late CashLotFifoEngine fifoEngine;
  late RecordCashExpenseUseCase recordCashExpense;
  late UpdateCashExpenseUseCase updateCashExpense;
  late RecordAtmWithdrawalUseCase recordAtm;
  late RecordCurrencyExchangeUseCase recordExchange;
  late RecordRefundUseCase recordRefund;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'financial_core_audit');
    tripRepo = TripRepository(db);
    expenseRepo = ExpenseRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    exchangeRepo = CurrencyExchangeRepository(db);
    refundRepo = ExpenseRefundRepository(db);
    fifoEngine = CashLotFifoEngine(lotRepo);
    recordCashExpense = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );
    updateCashExpense = UpdateCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      consumptionRepository: consumptionRepo,
      lotRepository: lotRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      refundRepository: refundRepo,
    );
    recordAtm = RecordAtmWithdrawalUseCase(
      appDatabase: db,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      expenseRepository: expenseRepo,
    );
    recordExchange = RecordCurrencyExchangeUseCase(
      appDatabase: db,
      exchangeEngine: CurrencyExchangeEngine(fifoEngine),
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
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
        id: 'trip-audit',
        name: 'Audit Trip',
        destination: 'Thailand',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Seeds initial cash through the production path
  /// ([CashWalletRepository.addCashTransaction]), which since Sprint 9A
  /// creates the lot + transaction + balance atomically. Returns the lot.
  Future<CashLot> seedInitialCash({
    required double amount,
    required String currency,
    required double homeAmount,
    DateTime? createdAt,
  }) async {
    final database = await db.database;
    final beforeIds = (await database.query(
      AppDatabase.cashLotsTable,
      columns: ['id'],
      where: 'trip_id = ?',
      whereArgs: [trip.id],
    ))
        .map((row) => row['id'] as String)
        .toSet();

    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: amount,
      currencyCode: currency,
      homeCurrencyAmount: homeAmount,
      homeCurrencyCode: 'SAR',
      createdAt: createdAt,
    );

    final afterRows = await database.query(
      AppDatabase.cashLotsTable,
      where: 'trip_id = ?',
      whereArgs: [trip.id],
    );
    final created = afterRows
        .where((row) => !beforeIds.contains(row['id'] as String))
        .map(CashLot.fromMap)
        .single;
    return created;
  }

  Expense cashExpense({
    required String title,
    required double amount,
    required String currency,
  }) {
    return Expense.create(
      tripId: trip.id,
      title: title,
      amount: amount,
      currencyCode: currency,
      transactionAmount: amount,
      transactionCurrency: currency,
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );
  }

  Future<Expense> createCardExpense({
    required String title,
    required double amount,
    required String currency,
    required double homeAmount,
  }) {
    return expenseRepo.createExpense(
      Expense.create(
        tripId: trip.id,
        title: title,
        amount: amount,
        currencyCode: currency,
        transactionAmount: amount,
        transactionCurrency: currency,
        convertedHomeAmount: homeAmount,
        homeCurrency: 'SAR',
        conversionRate: homeAmount / amount,
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS Purchase',
        category: 'Hotel',
      ),
    );
  }

  Future<double> balanceOf(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    for (final b in balances) {
      if (b.currencyCode == currency) return b.balanceAmount;
    }
    return 0;
  }

  /// Mirrors tripReportProvider: lot summaries → RemainingCashValue, active
  /// lots, active expenses, active refunds → TripReportCalculator.
  Future<TripReportSummary> buildReport() async {
    final expenses = await expenseRepo.getExpensesByTrip(trip.id);
    final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
    final summaries = await lotRepo.computeLotCurrencySummaries(
      tripId: trip.id,
      homeCurrencyCode: 'SAR',
    );
    final lotRemainingValues = summaries
        .where((s) => s.totalRemainingAmount > 0)
        .map((s) => RemainingCashValue(
              currencyCode: s.currencyCode,
              balanceAmount: s.totalRemainingAmount,
              effectiveRate: s.totalHomeAmount / s.totalRemainingAmount,
              homeAmount: s.totalHomeAmount,
              homeCurrency: s.homeCurrencyCode,
            ))
        .toList();
    final activeLots = await lotRepo.getActiveLotsForTrip(trip.id);
    return const TripReportCalculator().calculate(
      tripId: trip.id,
      tripName: trip.name,
      expenses: expenses,
      refunds: refunds,
      lotRemainingValues: lotRemainingValues,
      activeLots: activeLots,
    );
  }

  Future<List<Map<String, Object?>>> rawRows(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final database = await db.database;
    return database.query(table, where: where, whereArgs: whereArgs);
  }

  // ---------------------------------------------------------------------------
  // Scenario 1 — Initial Cash
  // ---------------------------------------------------------------------------

  group('Scenario 1 — Initial Cash', () {
    test(
        '1000 USD @ 3750 SAR, spend 200 USD → 800 remaining, 750 SAR consumed, '
        '3000 SAR remaining value', () async {
      final lot = await seedInitialCash(
        amount: 1000,
        currency: 'USD',
        homeAmount: 3750,
      );

      final result =
          await recordCashExpense.execute(cashExpense(
        title: 'Dinner',
        amount: 200,
        currency: 'USD',
      ));

      // USD balance = 800.
      expect(await balanceOf('USD'), closeTo(800, 1e-9));

      // Lot remaining = 800.
      final updatedLot = await lotRepo.getCashLotById(lot.id);
      expect(updatedLot!.remainingAmount, closeTo(800, 1e-9));
      expect(updatedLot.isFullyConsumed, isFalse);

      // Consumed home amount = 750 SAR.
      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(result.expense.id);
      expect(consumptions, hasLength(1));
      expect(consumptions.single.homeAmount, closeTo(750, 1e-9));
      expect(consumptions.single.homeCurrencyCode, 'SAR');
      expect(result.expense.convertedHomeAmount, closeTo(750, 1e-9));
      expect(result.expense.conversionRate, closeTo(3.75, 1e-9));

      // Remaining cash value = 3000 SAR (lot-based + report output).
      final summaries = await lotRepo.computeLotCurrencySummaries(
        tripId: trip.id,
        homeCurrencyCode: 'SAR',
      );
      expect(summaries, hasLength(1));
      expect(summaries.single.totalRemainingAmount, closeTo(800, 1e-9));
      expect(summaries.single.totalHomeAmount, closeTo(3000, 1e-9));

      final report = await buildReport();
      expect(report.remainingCashValues, hasLength(1));
      expect(report.remainingCashValues.single.homeAmount, closeTo(3000, 1e-9));
      expect(report.grossSpendingHomeAmount, closeTo(750, 1e-9));
      expect(report.netSpendingHomeAmount, closeTo(750, 1e-9));
      // Net trip cost = 750 − 3000 = −2250 (cash on hand exceeds spending).
      expect(report.netTripCostHomeAmount, closeTo(-2250, 1e-9));

      // cash_transactions audit: initial inflow + deduction, none reversed.
      final txns = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(txns, hasLength(2));
      expect(txns.every((t) => (t['is_reversed'] as int) == 0), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 2 — ATM Withdrawal
  // ---------------------------------------------------------------------------

  group('Scenario 2 — ATM Withdrawal', () {
    test(
        '20000 THB received, 2150 SAR charged, 30 SAR fee → lot basis 2120, '
        'fee is card expense, fee excluded from lot', () async {
      final result = await recordAtm.execute(
        tripId: trip.id,
        receivedAmount: 20000,
        receivedCurrency: 'THB',
        chargedAmount: 2150,
        chargedCurrency: 'SAR',
        feeAmount: 30,
        feeCurrency: 'SAR',
      );

      // Cash lot cost basis = 2120 SAR (fee excluded).
      final lot = await lotRepo.getCashLotById(result.cashLot.id);
      expect(lot!.homeCurrencyAmount, closeTo(2120, 1e-9));
      expect(lot.homeCurrencyCode, 'SAR');
      expect(lot.effectiveRate, closeTo(2120 / 20000, 1e-12));
      expect(lot.originalAmount, closeTo(20000, 1e-9));
      expect(lot.remainingAmount, closeTo(20000, 1e-9));
      expect(lot.sourceType, 'atm_withdrawal');

      // ATM fee is a card expense of 30 SAR.
      expect(result.feeExpense, isNotNull);
      expect(result.feeExpense!.transactionAmount, closeTo(30, 1e-9));
      expect(result.feeExpense!.transactionCurrency, 'SAR');
      expect(result.feeExpense!.paymentMethod, isNot('Cash'));
      expect(result.feeExpense!.paymentChannel, 'ATM Withdrawal Fee');
      final feeRow = await rawRows(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [result.feeExpense!.id],
      );
      expect(feeRow, hasLength(1));

      // THB balance increases by 20000.
      expect(await balanceOf('THB'), closeTo(20000, 1e-9));

      // cash_transactions: atm inflow carries lot_id and the cash portion only.
      final txns = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ? AND type = ?',
        whereArgs: [trip.id, 'atm_withdrawal'],
      );
      expect(txns, hasLength(1));
      expect(txns.single['lot_id'], lot.id);
      expect((txns.single['home_currency_amount'] as num).toDouble(),
          closeTo(2120, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 3 — Currency Exchange
  // ---------------------------------------------------------------------------

  group('Scenario 3 — Currency Exchange', () {
    test(
        '500 USD (basis 2100 SAR) → 16000 THB: cost transferred, '
        'spot rate stored only in currency_exchanges', () async {
      final usdLot = await seedInitialCash(
        amount: 500,
        currency: 'USD',
        homeAmount: 2100,
      );

      final result = await recordExchange.execute(
        tripId: trip.id,
        fromCurrencyCode: 'USD',
        fromAmount: 500,
        toCurrencyCode: 'THB',
        toAmount: 16000,
      );

      // USD lot fully consumed.
      final consumedUsd = await lotRepo.getCashLotById(usdLot.id);
      expect(consumedUsd!.remainingAmount, closeTo(0, 1e-9));
      expect(consumedUsd.isFullyConsumed, isTrue);

      // THB lot created with transferred cost basis = 2100 SAR.
      final thbLot = await lotRepo.getCashLotById(result.destinationLot.id);
      expect(thbLot, isNotNull);
      expect(thbLot!.currencyCode, 'THB');
      expect(thbLot.sourceType, 'exchange_in');
      expect(thbLot.originalAmount, closeTo(16000, 1e-9));
      expect(thbLot.homeCurrencyAmount, closeTo(2100, 1e-9));
      expect(thbLot.homeCurrencyCode, 'SAR');
      // No revaluation: effective rate derives from transferred basis only.
      expect(thbLot.effectiveRate, closeTo(2100 / 16000, 1e-12));

      // Spot rate stored only in currency_exchanges.
      final exchanges = await rawRows(
        AppDatabase.currencyExchangesTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(exchanges, hasLength(1));
      expect((exchanges.single['exchange_rate'] as num).toDouble(),
          closeTo(16000 / 500, 1e-9));
      expect(exchanges.single['to_lot_id'], thbLot.id);
      // Lot cost basis must NOT equal a spot-rate revaluation artifact;
      // verified above: basis == transferred 2100, rate == 2100/16000.

      // Consumption row links source lot to the exchange.
      final consumptions =
          await consumptionRepo.getConsumptionsByExchangeId(result.exchange.id);
      expect(consumptions, hasLength(1));
      expect(consumptions.single.lotId, usdLot.id);
      expect(consumptions.single.consumedAmount, closeTo(500, 1e-9));
      expect(consumptions.single.homeAmount, closeTo(2100, 1e-9));

      // Balances: USD 0, THB 16000.
      expect(await balanceOf('USD'), closeTo(0, 1e-9));
      expect(await balanceOf('THB'), closeTo(16000, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 4 — Cash Refund
  // ---------------------------------------------------------------------------

  group('Scenario 4 — Cash Refund', () {
    test(
        '2000 THB cash expense, 500 THB cash refund → refund lot created, '
        'returned_lot_id set, net spending reduced, balance increased',
        () async {
      await seedInitialCash(amount: 5000, currency: 'THB', homeAmount: 600);
      final created = await recordCashExpense.execute(
        cashExpense(title: 'Souvenirs', amount: 2000, currency: 'THB'),
      );
      // FIFO basis: 2000 × 0.12 = 240 SAR.
      expect(created.expense.convertedHomeAmount, closeTo(240, 1e-9));

      final balanceBefore = await balanceOf('THB');
      final netBefore = (await buildReport()).netSpendingHomeAmount!;

      // Refund inherits the expense's cost basis proportionally:
      // 500/2000 × 240 = 60 SAR.
      final refundResult = await recordRefund.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: created.expense.id,
        refundAmount: 500,
        refundCurrency: 'THB',
        homeAmount: 60,
        homeCurrency: 'SAR',
        linkedExpense: created.expense,
      );

      // Refund row created.
      final refundRows = await rawRows(
        AppDatabase.expenseRefundsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(refundRows, hasLength(1));
      expect(refundRows.single['expense_id'], created.expense.id);
      expect((refundRows.single['is_reversed'] as int), 0);

      // Refund cash lot created with inherited basis; returned_lot_id set.
      final returnedLotId = refundRows.single['returned_lot_id'] as String?;
      expect(returnedLotId, isNotNull);
      expect(returnedLotId, refundResult.cashLot!.id);
      final refundLot = await lotRepo.getCashLotById(returnedLotId!);
      expect(refundLot!.sourceType, 'cash_refund');
      expect(refundLot.originalAmount, closeTo(500, 1e-9));
      expect(refundLot.remainingAmount, closeTo(500, 1e-9));
      expect(refundLot.homeCurrencyAmount, closeTo(60, 1e-9));
      expect(refundLot.effectiveRate, closeTo(0.12, 1e-12));
      expect(refundLot.sourceRefId, refundResult.refund.id);

      // Cash balance increased by 500.
      expect(await balanceOf('THB'), closeTo(balanceBefore + 500, 1e-9));

      // Net spending reduced by 60 SAR.
      final report = await buildReport();
      expect(report.refundHomeAmount, closeTo(60, 1e-9));
      expect(report.netSpendingHomeAmount, closeTo(netBefore - 60, 1e-9));

      // cash_transactions: cash_refund row exists, linked to the lot.
      final refundTxns = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ? AND type = ?',
        whereArgs: [trip.id, 'cash_refund'],
      );
      expect(refundTxns, hasLength(1));
      expect(refundTxns.single['lot_id'], returnedLotId);
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 5 — Card Refund
  // ---------------------------------------------------------------------------

  group('Scenario 5 — Card Refund', () {
    test('500 SAR card expense, 100 SAR card refund → no cash impact, '
        'net spending reduced by 100', () async {
      final hotel = await createCardExpense(
        title: 'Hotel',
        amount: 500,
        currency: 'SAR',
        homeAmount: 500,
      );

      final result = await recordRefund.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: hotel.id,
        refundAmount: 100,
        refundCurrency: 'SAR',
        homeAmount: 100,
        homeCurrency: 'SAR',
        linkedExpense: hotel,
      );

      // No cash lot.
      expect(result.cashLot, isNull);
      expect(result.cashTransaction, isNull);
      final lots = await rawRows(
        AppDatabase.cashLotsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(lots, isEmpty);
      final refundRows = await rawRows(
        AppDatabase.expenseRefundsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(refundRows, hasLength(1));
      expect(refundRows.single['returned_lot_id'], isNull);
      expect(refundRows.single['destination'], 'card');

      // No cash balance change / no cash transactions.
      expect(await walletRepo.getBalancesByTrip(trip.id), isEmpty);
      final txns = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(txns, isEmpty);

      // Net spending reduced by 100 SAR.
      final report = await buildReport();
      expect(report.grossSpendingHomeAmount, closeTo(500, 1e-9));
      expect(report.refundHomeAmount, closeTo(100, 1e-9));
      expect(report.netSpendingHomeAmount, closeTo(400, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 6 — Edit Cash Expense (Reverse + Recreate)
  // ---------------------------------------------------------------------------

  group('Scenario 6 — Edit Cash Expense', () {
    test('1700 across 3 lots, edit to 1200, then spend 400 → exact FIFO state',
        () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      final t2 = DateTime.utc(2026, 1, 3);
      // Rate 0.1 SAR per THB on all lots.
      final lot1 = await seedInitialCash(
          amount: 1000, currency: 'THB', homeAmount: 100, createdAt: t0);
      final lot2 = await seedInitialCash(
          amount: 500, currency: 'THB', homeAmount: 50, createdAt: t1);
      final lot3 = await seedInitialCash(
          amount: 500, currency: 'THB', homeAmount: 50, createdAt: t2);

      Future<double> remaining(String lotId) async =>
          (await lotRepo.getCashLotById(lotId))!.remainingAmount;

      // ── Create Expense A = 1700 ───────────────────────────────────────────
      final a = await recordCashExpense.execute(
        cashExpense(title: 'Expense A', amount: 1700, currency: 'THB'),
      );
      expect(await remaining(lot1.id), closeTo(0, 1e-9));
      expect(await remaining(lot2.id), closeTo(0, 1e-9));
      expect(await remaining(lot3.id), closeTo(300, 1e-9));

      // ── Edit Expense A → 1200 ─────────────────────────────────────────────
      final edited = await updateCashExpense.execute(
        a.expense.copyWith(amount: 1200, transactionAmount: 1200),
      );

      // Old consumptions reversed.
      final allConsumptions =
          await consumptionRepo.getConsumptionsByExpenseId(a.expense.id);
      final reversed = allConsumptions.where((c) => c.isReversed).toList();
      final active = allConsumptions.where((c) => !c.isReversed).toList();
      expect(reversed, hasLength(3)); // 1000 + 500 + 200 original split
      expect(active, hasLength(2)); // 1000 + 200 new split

      // New FIFO allocation: lot1 = 1000, lot2 = 200, lot3 = 0.
      final byLot = {for (final c in active) c.lotId: c.consumedAmount};
      expect(byLot[lot1.id], closeTo(1000, 1e-9));
      expect(byLot[lot2.id], closeTo(200, 1e-9));
      expect(byLot.containsKey(lot3.id), isFalse);

      expect(await remaining(lot1.id), closeTo(0, 1e-9));
      expect(await remaining(lot2.id), closeTo(300, 1e-9));
      expect(await remaining(lot3.id), closeTo(500, 1e-9));

      // FIFO cost basis refreshed: 1200 × 0.1 = 120 SAR.
      expect(edited.expense.convertedHomeAmount, closeTo(120, 1e-9));

      // Old deduction reversed, new deduction active.
      final deductions = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ? AND type = ?',
        whereArgs: [trip.id, 'cash_expense_deduction'],
      );
      expect(deductions.where((d) => (d['is_reversed'] as int) == 1),
          hasLength(1));
      expect(deductions.where((d) => (d['is_reversed'] as int) == 0),
          hasLength(1));

      // Balance: 2000 − 1200 = 800.
      expect(await balanceOf('THB'), closeTo(800, 1e-9));

      // ── Create Expense B = 400 ────────────────────────────────────────────
      final b = await recordCashExpense.execute(
        cashExpense(title: 'Expense B', amount: 400, currency: 'THB'),
      );
      final bConsumptions =
          await consumptionRepo.getConsumptionsByExpenseId(b.expense.id);
      final bByLot = {
        for (final c in bConsumptions.where((c) => !c.isReversed))
          c.lotId: c.consumedAmount,
      };
      expect(bByLot[lot2.id], closeTo(300, 1e-9));
      expect(bByLot[lot3.id], closeTo(100, 1e-9));

      // Final lot state: lot1 = 0, lot2 = 0, lot3 = 400.
      expect(await remaining(lot1.id), closeTo(0, 1e-9));
      expect(await remaining(lot2.id), closeTo(0, 1e-9));
      expect(await remaining(lot3.id), closeTo(400, 1e-9));
      expect(await balanceOf('THB'), closeTo(400, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 7 — Delete Cash Expense (Reverse + Mark Reversed)
  // ---------------------------------------------------------------------------

  group('Scenario 7 — Delete Cash Expense', () {
    test('delete restores lot, reverses consumptions/transaction, '
        'keeps expense row with is_reversed = 1, excluded from report',
        () async {
      final lot = await seedInitialCash(
          amount: 1000, currency: 'THB', homeAmount: 100);
      final created = await recordCashExpense.execute(
        cashExpense(title: 'Taxi', amount: 600, currency: 'THB'),
      );
      expect(await balanceOf('THB'), closeTo(400, 1e-9));

      await updateCashExpense.reverseAndDelete(created.expense.id);

      // Expense row remains, is_reversed = true, reversed_at set.
      final rows = await rawRows(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [created.expense.id],
      );
      expect(rows, hasLength(1));
      expect(rows.single['is_reversed'], 1);
      expect(rows.single['reversed_at'], isNotNull);

      // Lot remaining amount restored.
      final restoredLot = await lotRepo.getCashLotById(lot.id);
      expect(restoredLot!.remainingAmount, closeTo(1000, 1e-9));
      expect(restoredLot.isFullyConsumed, isFalse);

      // Consumptions reversed.
      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(created.expense.id);
      expect(consumptions, isNotEmpty);
      expect(consumptions.every((c) => c.isReversed), isTrue);

      // Cash transaction reversed; balance restored.
      final deductions = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ? AND type = ?',
        whereArgs: [trip.id, 'cash_expense_deduction'],
      );
      expect(deductions, hasLength(1));
      expect(deductions.single['is_reversed'], 1);
      expect(await balanceOf('THB'), closeTo(1000, 1e-9));

      // Report excludes the reversed expense.
      final visible = await expenseRepo.getExpensesByTrip(trip.id);
      expect(visible, isEmpty);
      final report = await buildReport();
      expect(report.totalExpenseCount, 0);
      expect(report.grossSpendingHomeAmount, isNull);
      expect(report.remainingCashValues.single.homeAmount, closeTo(100, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // Scenario 8 — Mixed Real Trip
  // ---------------------------------------------------------------------------

  group('Scenario 8 — Mixed Real Trip', () {
    test('full trip: initial cash, exchange, ATM, expenses, refunds, '
        'edit, delete → all balances, lots, and report values correct',
        () async {
      final t0 = DateTime.utc(2026, 3, 1);
      final t1 = DateTime.utc(2026, 3, 2);
      final t2 = DateTime.utc(2026, 3, 3);

      // 1. Initial cash: 1000 USD @ 3750 SAR (rate 3.75).
      final usdLot = await seedInitialCash(
          amount: 1000, currency: 'USD', homeAmount: 3750, createdAt: t0);

      // 2. Exchange 500 USD → 16000 THB (transfers 1875 SAR of basis).
      final exchange = await recordExchange.execute(
        tripId: trip.id,
        fromCurrencyCode: 'USD',
        fromAmount: 500,
        toCurrencyCode: 'THB',
        toAmount: 16000,
        createdAt: t1,
      );
      final exLotId = exchange.destinationLot.id;
      const exRate = 1875 / 16000; // 0.1171875 SAR per THB

      // 3. ATM 20000 THB, charged 2150 SAR, fee 30 SAR → lot basis 2120.
      final atm = await recordAtm.execute(
        tripId: trip.id,
        receivedAmount: 20000,
        receivedCurrency: 'THB',
        chargedAmount: 2150,
        chargedCurrency: 'SAR',
        feeAmount: 30,
        feeCurrency: 'SAR',
        createdAt: t2,
      );
      final atmLotId = atm.cashLot.id;

      // 4–5. Cash expenses: food 1000 THB, taxi 500 THB (consume exchange lot).
      final food = await recordCashExpense.execute(
        cashExpense(title: 'Food', amount: 1000, currency: 'THB'),
      );
      final taxi = await recordCashExpense.execute(
        cashExpense(title: 'Taxi', amount: 500, currency: 'THB'),
      );
      // Extra cash expense to be deleted later.
      final snacks = await recordCashExpense.execute(
        cashExpense(title: 'Snacks', amount: 300, currency: 'THB'),
      );

      // 6. Card expense: hotel 800 SAR.
      final hotel = await createCardExpense(
        title: 'Hotel',
        amount: 800,
        currency: 'SAR',
        homeAmount: 800,
      );

      // 7. Cash refund 200 THB on food (inherits 200 × exRate SAR).
      final foodRefundHome = 200 * exRate; // 23.4375
      await recordRefund.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: food.expense.id,
        refundAmount: 200,
        refundCurrency: 'THB',
        homeAmount: foodRefundHome,
        homeCurrency: 'SAR',
        linkedExpense: food.expense,
      );

      // 8. Card refund 100 SAR on hotel.
      await recordRefund.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        expenseId: hotel.id,
        refundAmount: 100,
        refundCurrency: 'SAR',
        homeAmount: 100,
        homeCurrency: 'SAR',
        linkedExpense: hotel,
      );

      // 9. Edit taxi 500 → 700 (reverse + recreate FIFO).
      await updateCashExpense.execute(
        taxi.expense.copyWith(amount: 700, transactionAmount: 700),
      );

      // 10. Delete snacks (reverse + mark reversed).
      await updateCashExpense.reverseAndDelete(snacks.expense.id);

      // ── Balances: no negatives, exact values ─────────────────────────────
      final balances = await walletRepo.getBalancesByTrip(trip.id);
      for (final b in balances) {
        expect(b.balanceAmount, greaterThanOrEqualTo(0),
            reason: 'negative balance for ${b.currencyCode}');
      }
      // USD: 1000 − 500 = 500.
      expect(await balanceOf('USD'), closeTo(500, 1e-9));
      // THB: 16000 + 20000 − 1000 − 700 + 200 = 34500 (snacks reversed).
      expect(await balanceOf('THB'), closeTo(34500, 1e-9));

      // ── Active lots correct ───────────────────────────────────────────────
      final activeLots = await lotRepo.getActiveLotsForTrip(trip.id);
      expect(activeLots, hasLength(4));
      final lotById = {for (final l in activeLots) l.id: l};
      // USD initial lot: 500 remaining of 1000.
      expect(lotById[usdLot.id]!.remainingAmount, closeTo(500, 1e-9));
      // Exchange lot: 16000 − 1000 (food) − 700 (edited taxi) = 14300.
      expect(lotById[exLotId]!.remainingAmount, closeTo(14300, 1e-9));
      // ATM lot untouched: 20000.
      expect(lotById[atmLotId]!.remainingAmount, closeTo(20000, 1e-9));
      // Refund lot: 200.
      final refundLot = activeLots
          .firstWhere((l) => l.sourceType == 'cash_refund');
      expect(refundLot.remainingAmount, closeTo(200, 1e-9));
      expect(refundLot.homeCurrencyAmount, closeTo(foodRefundHome, 1e-9));

      // Lot conservation: original − Σ(active consumptions) == remaining.
      for (final lot in activeLots) {
        final consumed =
            (await consumptionRepo.getConsumptionsByLotId(lot.id))
                .where((c) => !c.isReversed)
                .fold<double>(0, (sum, c) => sum + c.consumedAmount);
        expect(lot.originalAmount - consumed,
            closeTo(lot.remainingAmount, 1e-9),
            reason: 'lot ${lot.id} conservation violated');
      }

      // ── Reversed rows excluded from report ───────────────────────────────
      final visibleExpenses = await expenseRepo.getExpensesByTrip(trip.id);
      expect(visibleExpenses.map((e) => e.title),
          isNot(contains('Snacks')));
      // Visible: food, taxi, hotel, ATM fee.
      expect(visibleExpenses, hasLength(4));

      // ── Report values ─────────────────────────────────────────────────────
      final report = await buildReport();

      // Gross spending (SAR): food 1000×exRate + taxi 700×exRate + hotel 800.
      // NOTE: the ATM fee card expense carries no convertedHomeAmount, so it
      // is excluded from home-currency gross (documented audit finding).
      final foodHome = 1000 * exRate; // 117.1875
      final taxiHome = 700 * exRate; // 82.03125
      final expectedGross = foodHome + taxiHome + 800;
      expect(report.grossSpendingHomeAmount, closeTo(expectedGross, 1e-9));

      // Net spending = gross − refunds (23.4375 + 100).
      final expectedNet = expectedGross - (foodRefundHome + 100);
      expect(report.refundHomeAmount, closeTo(foodRefundHome + 100, 1e-9));
      expect(report.netSpendingHomeAmount, closeTo(expectedNet, 1e-9));

      // Remaining cash value (home):
      //   USD: 500 × 3.75 = 1875
      //   THB: 14300×exRate + 20000×0.106 + 200×exRate
      final expectedThbHome = 14300 * exRate + 20000 * 0.106 + 200 * exRate;
      final remainingByCurrency = {
        for (final v in report.remainingCashValues) v.currencyCode: v,
      };
      expect(remainingByCurrency['USD']!.homeAmount, closeTo(1875, 1e-9));
      expect(remainingByCurrency['THB']!.homeAmount,
          closeTo(expectedThbHome, 1e-9));

      // Net trip cost = net spending − total remaining cash (home).
      final expectedNetTripCost =
          expectedNet - (1875 + expectedThbHome);
      expect(report.netTripCostHomeAmount,
          closeTo(expectedNetTripCost, 1e-9));

      // ── Cash acquisition summary ──────────────────────────────────────────
      final acquisition = {
        for (final e in report.cashAcquisitionSummary)
          '${e.sourceType}|${e.originalCurrency}': e,
      };
      expect(acquisition['initial_cash|USD']!.totalOriginalAmount,
          closeTo(1000, 1e-9));
      expect(acquisition['initial_cash|USD']!.totalHomeAmount,
          closeTo(3750, 1e-9));
      expect(acquisition['exchange_in|THB']!.totalOriginalAmount,
          closeTo(16000, 1e-9));
      expect(acquisition['exchange_in|THB']!.totalHomeAmount,
          closeTo(1875, 1e-9));
      expect(acquisition['atm_withdrawal|THB']!.totalOriginalAmount,
          closeTo(20000, 1e-9));
      expect(acquisition['atm_withdrawal|THB']!.totalHomeAmount,
          closeTo(2120, 1e-9));
      expect(acquisition['cash_refund|THB']!.totalOriginalAmount,
          closeTo(200, 1e-9));

      // ── Payment source summary ────────────────────────────────────────────
      final paymentBuckets = {
        for (final e in report.paymentSourceSummary)
          '${e.paymentType}|${e.transactionCurrency}': e,
      };
      // Cash THB: food 1000 + edited taxi 700 = 1700 (snacks excluded).
      expect(paymentBuckets['cash|THB']!.totalTransactionAmount,
          closeTo(1700, 1e-9));
      expect(paymentBuckets['cash|THB']!.totalHomeAmount,
          closeTo(foodHome + taxiHome, 1e-9));
      // Credit Card expenses are normalised to 'card' in payment source summary.
      expect(paymentBuckets['card|SAR']!.totalTransactionAmount,
          closeTo(830, 1e-9));

      // ── Raw-table audit: every reversed artifact consistent ──────────────
      final snackRow = await rawRows(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [snacks.expense.id],
      );
      expect(snackRow.single['is_reversed'], 1);

      final allTxns = await rawRows(
        AppDatabase.cashTransactionsTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      // Recompute balances from active transactions and compare with the
      // trip_cash_balances cache (derived-state integrity).
      final recomputed = <String, double>{};
      for (final t in allTxns) {
        if ((t['is_reversed'] as int) == 1) continue;
        final type = CashTransactionTypeCodec.fromValue(t['type'] as String);
        final currency = t['currency_code'] as String;
        final amount = (t['amount'] as num).toDouble();
        recomputed[currency] =
            (recomputed[currency] ?? 0) + type.signedDelta(amount);
      }
      for (final b in balances) {
        expect(recomputed[b.currencyCode] ?? 0,
            closeTo(b.balanceAmount, 1e-9),
            reason:
                'trip_cash_balances cache out of sync for ${b.currencyCode}');
      }
    });
  });
}
