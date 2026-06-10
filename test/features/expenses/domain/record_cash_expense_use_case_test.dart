import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late ExpenseRepository expenseRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late CashLotFifoEngine fifoEngine;
  late RecordCashExpenseUseCase useCase;
  late Trip trip;

  var seq = 0;
  String nextId([String prefix = 'lot']) => '$prefix-${++seq}';

  setUp(() async {
    seq = 0;
    db = createIsolatedAppDatabase(prefix: 'record_cash_expense');
    tripRepo = TripRepository(db);
    expenseRepo = ExpenseRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    fifoEngine = CashLotFifoEngine(lotRepo);
    useCase = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-rc',
        name: 'RC Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<CashLot> insertLot({
    required double amount,
    String currency = 'JPY',
    double? rate,
    String? homeCode,
    String? id,
    DateTime? createdAt,
  }) async {
    final lot = CashLot.create(
      id: id ?? nextId(),
      tripId: trip.id,
      sourceType: 'initial_cash',
      sourceRefType: 'cash_transaction',
      sourceRefId: 'src-${id ?? seq}',
      currencyCode: currency,
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: (rate != null && homeCode != null) ? amount * rate : null,
      homeCurrencyCode: homeCode,
      effectiveRate: rate,
      createdAt: createdAt,
    );
    return lotRepo.insertCashLot(lot);
  }

  Expense cashExpense({
    double amount = 1000,
    String currency = 'JPY',
  }) {
    return Expense.create(
      tripId: trip.id,
      title: 'Ramen',
      amount: amount,
      currencyCode: currency,
      transactionAmount: amount,
      transactionCurrency: currency,
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Cash expense consumes single lot
  // ---------------------------------------------------------------------------

  group('1 — consumes single lot', () {
    test('lot remaining_amount decreases by expense amount', () async {
      final lot = await insertLot(amount: 5000);

      await useCase.execute(cashExpense(amount: 3000));

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(2000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Cash expense consumes multiple lots FIFO
  // ---------------------------------------------------------------------------

  group('2 — multi-lot FIFO consumption', () {
    test('oldest lot is exhausted first, then draws from newer lot', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      final lot1 = await insertLot(amount: 800, id: 'lot-a', createdAt: t0);
      final lot2 = await insertLot(amount: 2000, id: 'lot-b', createdAt: t1);

      await useCase.execute(cashExpense(amount: 1500));

      final l1 = await lotRepo.getCashLotById(lot1.id);
      final l2 = await lotRepo.getCashLotById(lot2.id);

      expect(l1!.remainingAmount, closeTo(0, 1e-6));
      expect(l1.isFullyConsumed, isTrue);
      expect(l2!.remainingAmount, closeTo(1300, 1e-6));
      expect(l2.isFullyConsumed, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Creates cash_lot_consumptions records
  // ---------------------------------------------------------------------------

  group('3 — creates consumption records', () {
    test('one consumption row per lot drawn from', () async {
      final t0 = DateTime.utc(2026, 2, 1);
      final t1 = DateTime.utc(2026, 2, 2);
      final lot1 = await insertLot(amount: 600, id: 'lot-c', createdAt: t0);
      final lot2 = await insertLot(amount: 1000, id: 'lot-d', createdAt: t1);

      final result = await useCase.execute(cashExpense(amount: 900));

      final c1 = await consumptionRepo.getConsumptionsByLotId(lot1.id);
      final c2 = await consumptionRepo.getConsumptionsByLotId(lot2.id);

      expect(c1, hasLength(1));
      expect(c1.first.expenseId, result.expense.id);
      expect(c1.first.consumedAmount, closeTo(600, 1e-6));
      expect(c1.first.consumptionType, 'cash_expense');

      expect(c2, hasLength(1));
      expect(c2.first.consumedAmount, closeTo(300, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Updates cash_lots.remaining_amount
  // ---------------------------------------------------------------------------

  group('4 — updates remaining_amount', () {
    test('remaining_amount reflects consumed portion exactly', () async {
      final lot = await insertLot(amount: 4000);

      await useCase.execute(cashExpense(amount: 1234));

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(2766, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Marks fully consumed lot
  // ---------------------------------------------------------------------------

  group('5 — marks fully consumed lot', () {
    test('is_fully_consumed = 1 when expense drains entire lot', () async {
      final lot = await insertLot(amount: 500);

      await useCase.execute(cashExpense(amount: 500));

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.remainingAmount, closeTo(0, 1e-6));
      expect(updated.isFullyConsumed, isTrue);
    });

    test('lot is NOT marked fully consumed on partial draw', () async {
      final lot = await insertLot(amount: 2000);

      await useCase.execute(cashExpense(amount: 500));

      final updated = await lotRepo.getCashLotById(lot.id);
      expect(updated!.isFullyConsumed, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Fails on insufficient balance
  // ---------------------------------------------------------------------------

  group('6 — fails on insufficient balance', () {
    test('throws InsufficientCashException when lots total < expense amount', () async {
      await insertLot(amount: 200);

      expect(
        () => useCase.execute(cashExpense(amount: 1000)),
        throwsA(
          isA<InsufficientCashException>()
              .having((e) => e.available, 'available', closeTo(200, 1e-6))
              .having((e) => e.required, 'required', closeTo(1000, 1e-6)),
        ),
      );
    });

    test('throws InsufficientCashException when no lots exist', () async {
      expect(
        () => useCase.execute(cashExpense(amount: 500)),
        throwsA(isA<InsufficientCashException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Failed expense leaves no partial DB writes
  // ---------------------------------------------------------------------------

  group('7 — atomicity — no partial DB writes on failure', () {
    test('expense row not written when insufficient balance', () async {
      await insertLot(amount: 100); // too small

      try {
        await useCase.execute(cashExpense(amount: 5000));
      } on InsufficientCashException {
        // expected
      }

      final expenses = await expenseRepo.getExpensesByTrip(trip.id);
      expect(expenses, isEmpty);
    });

    test('consumption records not written when insufficient balance', () async {
      final lot = await insertLot(amount: 100);

      try {
        await useCase.execute(cashExpense(amount: 5000));
      } on InsufficientCashException {
        // expected
      }

      final consumptions = await consumptionRepo.getConsumptionsByLotId(lot.id);
      expect(consumptions, isEmpty);
    });

    test('lot remaining_amount unchanged when expense fails', () async {
      final lot = await insertLot(amount: 100);

      try {
        await useCase.execute(cashExpense(amount: 5000));
      } on InsufficientCashException {
        // expected
      }

      final unchanged = await lotRepo.getCashLotById(lot.id);
      expect(unchanged!.remainingAmount, closeTo(100, 1e-6));
    });

    test('no cash_transactions row written when insufficient balance', () async {
      await insertLot(amount: 100);

      try {
        await useCase.execute(cashExpense(amount: 5000));
      } on InsufficientCashException {
        // expected
      }

      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(txns.where((t) => t.type == CashTransactionType.cashExpenseDeduction), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 8. expense.convertedHomeAmount == SUM(consumption.homeAmount)
  // ---------------------------------------------------------------------------

  group('8 — cost basis derivation', () {
    test('convertedHomeAmount == SUM of consumed plan homeAmounts', () async {
      final t0 = DateTime.utc(2026, 3, 1);
      final t1 = DateTime.utc(2026, 3, 2);
      // Lot A: 1000 JPY @ 0.025 SAR/JPY → homeAmount = 25 SAR
      await insertLot(amount: 1000, rate: 0.025, homeCode: 'SAR', id: 'lot-e', createdAt: t0);
      // Lot B: 2000 JPY @ 0.030 SAR/JPY → homeAmount = 60 SAR
      await insertLot(amount: 2000, rate: 0.030, homeCode: 'SAR', id: 'lot-f', createdAt: t1);

      // Expense draws 2500 JPY: all of lot A (25 SAR) + 1500 from lot B (45 SAR) = 70 SAR
      final result = await useCase.execute(cashExpense(amount: 2500));

      expect(result.expense.convertedHomeAmount, closeTo(70.0, 1e-4));
      expect(result.expense.homeCurrency, 'SAR');
      // conversionRate = 70 / 2500 = 0.028
      expect(result.expense.conversionRate, closeTo(0.028, 1e-6));
    });

    test('convertedHomeAmount is null when all lots lack a cost basis', () async {
      await insertLot(amount: 3000); // no rate/homeCode

      final result = await useCase.execute(cashExpense(amount: 1000));

      expect(result.expense.convertedHomeAmount, isNull);
      expect(result.expense.homeCurrency, isNull);
      expect(result.expense.conversionRate, isNull);
    });

    test('partial basis: only non-null lot homeAmounts are summed', () async {
      final t0 = DateTime.utc(2026, 4, 1);
      final t1 = DateTime.utc(2026, 4, 2);
      await insertLot(amount: 500, id: 'lot-nocost', createdAt: t0); // no basis
      await insertLot(amount: 1000, rate: 0.025, homeCode: 'SAR', id: 'lot-withcost', createdAt: t1);

      // Draw 1200 JPY: 500 from no-cost lot + 700 from cost lot
      // 700 × 0.025 = 17.5 SAR
      final result = await useCase.execute(cashExpense(amount: 1200));

      expect(result.expense.convertedHomeAmount, closeTo(17.5, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 9. cash_transaction linked to expense but not to lot
  // ---------------------------------------------------------------------------

  group('9 — cash_transaction fields', () {
    test('cash_transaction has expense_id set and lot_id = null', () async {
      await insertLot(amount: 5000);

      final result = await useCase.execute(cashExpense(amount: 2000));

      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      final deductionTxns = txns
          .where((t) => t.type == CashTransactionType.cashExpenseDeduction)
          .toList();

      expect(deductionTxns, hasLength(1));
      expect(deductionTxns.first.expenseId, result.expense.id);
      expect(deductionTxns.first.lotId, isNull);
      expect(deductionTxns.first.exchangeId, isNull);
    });

    test('cash_transaction amount matches expense transactionAmount', () async {
      await insertLot(amount: 5000);

      await useCase.execute(cashExpense(amount: 1234));

      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      final deduction = txns
          .firstWhere((t) => t.type == CashTransactionType.cashExpenseDeduction);

      expect(deduction.amount, closeTo(1234, 1e-6));
      expect(deduction.currencyCode, 'JPY');
    });

    test('trip_cash_balances decreases by expense amount', () async {
      // First add some balance to the wallet
      await walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 5000,
        currencyCode: 'JPY',
      );
      await insertLot(amount: 5000);

      await useCase.execute(cashExpense(amount: 1500));

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final jpyBalance = balances
          .firstWhere((b) => b.currencyCode == 'JPY')
          .balanceAmount;
      // 5000 (initial) - 1500 (expense deduction) = 3500
      expect(jpyBalance, closeTo(3500, 1e-4));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Card expense path is unaffected
  // ---------------------------------------------------------------------------

  group('10 — card expense unaffected', () {
    test('card expense can still be created without any lots', () async {
      // No lots in DB — should succeed because card expenses skip FIFO
      final cardExpense = Expense.create(
        tripId: trip.id,
        title: 'Hotel',
        amount: 500,
        currencyCode: 'USD',
        transactionAmount: 500,
        transactionCurrency: 'USD',
        paymentMethod: 'Card',
        paymentChannel: 'POS Purchase',
        category: 'Accommodation',
      );

      // Card expenses still go through the regular ExpenseRepository path
      final created = await expenseRepo.createExpense(cardExpense);
      expect(created.id, isNotEmpty);
      expect(created.paymentMethod, 'Card');

      // No lot consumptions should exist
      final allConsumptions =
          await consumptionRepo.getConsumptionsByExpenseId(created.id);
      expect(allConsumptions, isEmpty);

      // No cash transactions for this expense
      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(
        txns.where((t) => t.expenseId == created.id),
        isEmpty,
      );
    });
  });
}
