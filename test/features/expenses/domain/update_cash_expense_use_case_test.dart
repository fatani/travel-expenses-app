// Sprint 8B — UpdateCashExpenseUseCase integration tests
//
// Uses sqflite_common_ffi for a real in-memory SQLite database so FIFO lot
// state is verified end-to-end.  All writes happen through production code;
// tests only read back rows through repositories.
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_exception.dart';
import 'package:travel_expenses/features/expenses/domain/update_cash_expense_use_case.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
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
  late ExpenseRefundRepository refundRepo;
  late CashLotFifoEngine fifoEngine;
  late RecordCashExpenseUseCase createUseCase;
  late UpdateCashExpenseUseCase updateUseCase;
  late Trip trip;

  var seq = 0;
  String nextId([String prefix = 'lot']) => '$prefix-${++seq}';

  setUp(() async {
    seq = 0;
    db = createIsolatedAppDatabase(prefix: 'update_cash_expense');
    tripRepo = TripRepository(db);
    expenseRepo = ExpenseRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    refundRepo = ExpenseRefundRepository(db);
    fifoEngine = CashLotFifoEngine(lotRepo);

    createUseCase = RecordCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );

    updateUseCase = UpdateCashExpenseUseCase(
      appDatabase: db,
      expenseRepository: expenseRepo,
      consumptionRepository: consumptionRepo,
      lotRepository: lotRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifoEngine,
      refundRepository: refundRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-uc',
        name: 'UC Trip',
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
    double rate = 0.035,
    String homeCode = 'SAR',
    String? id,
    DateTime? createdAt,
  }) async {
    final lotId = id ?? nextId();
    final lot = CashLot.create(
      id: lotId,
      tripId: trip.id,
      sourceType: 'initial_cash',
      sourceRefType: 'cash_transaction',
      sourceRefId: 'src-$lotId',
      currencyCode: currency,
      originalAmount: amount,
      remainingAmount: amount,
      homeCurrencyAmount: amount * rate,
      homeCurrencyCode: homeCode,
      effectiveRate: rate,
      createdAt: createdAt,
    );
    final inserted = await lotRepo.insertCashLot(lot);
    // Seed trip_cash_balances so deduction tracking is accurate.
    // In production, RecordAtmWithdrawalUseCase does this inside a transaction.
    final dbRef = await db.database;
    await dbRef.transaction((txn) async {
      await walletRepo.recordAtmInflow(
        txn: txn,
        tripId: trip.id,
        lotId: inserted.id,
        amount: amount,
        currencyCode: currency,
        homeCurrencyAmount: amount * rate,
        homeCurrencyCode: homeCode,
        createdAt: createdAt,
      );
    });
    return inserted;
  }

  Expense cashExpense({
    String id = '',
    double amount = 1000,
    String currency = 'JPY',
  }) {
    return Expense.create(
      id: id,
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

  /// Creates a cash expense via FIFO and returns it.
  Future<Expense> createCash({double amount = 1000, String currency = 'JPY'}) async {
    final result = await createUseCase.execute(cashExpense(amount: amount, currency: currency));
    return result.expense;
  }

  // ---------------------------------------------------------------------------
  // 1. Edit amount — larger
  // ---------------------------------------------------------------------------

  group('1 — edit amount larger', () {
    test('lot remaining_amount is correctly decreased after larger edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      // Before edit: lot has 4000 remaining
      final lotBefore = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      expect(lotBefore.remainingAmount, closeTo(4000, 1e-6));

      // Edit to 2500
      final updated = exp.copyWith(
        amount: 2500,
        transactionAmount: 2500,
      );
      await updateUseCase.execute(updated);

      final lotAfter = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      // Net: 5000 − 2500 = 2500 remaining
      expect(lotAfter.remainingAmount, closeTo(2500, 1e-6));
    });

    test('convertedHomeAmount is re-derived from FIFO after larger edit', () async {
      await insertLot(amount: 5000, rate: 0.035);
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(amount: 2000, transactionAmount: 2000);
      final result = await updateUseCase.execute(updated);

      // 2000 JPY × 0.035 = 70 SAR
      expect(result.expense.convertedHomeAmount, closeTo(70.0, 1e-6));
      expect(result.expense.conversionRate, closeTo(0.035, 1e-9));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Edit amount — smaller
  // ---------------------------------------------------------------------------

  group('2 — edit amount smaller', () {
    test('lot remaining_amount is restored after smaller edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 3000);

      final updated = exp.copyWith(amount: 1000, transactionAmount: 1000);
      await updateUseCase.execute(updated);

      final lotAfter = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      // Net: 5000 − 1000 = 4000 remaining
      expect(lotAfter.remainingAmount, closeTo(4000, 1e-6));
    });

    test('old consumption rows are marked reversed', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 3000);

      final updated = exp.copyWith(amount: 1000, transactionAmount: 1000);
      await updateUseCase.execute(updated);

      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(exp.id);
      // Original row reversed, new row active
      final reversed = consumptions.where((c) => c.isReversed).toList();
      final active = consumptions.where((c) => !c.isReversed).toList();
      expect(reversed.length, 1);
      expect(active.length, 1);
      expect(active.first.consumedAmount, closeTo(1000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Edit currency
  // ---------------------------------------------------------------------------

  group('3 — edit currency', () {
    test('lot for old currency is restored, lot for new currency consumed', () async {
      final lotJpy = await insertLot(amount: 5000, currency: 'JPY', id: 'lot-jpy');
      final lotEur = await insertLot(
          amount: 200, currency: 'EUR', rate: 3.97, homeCode: 'SAR', id: 'lot-eur');
      final exp = await createCash(amount: 1000, currency: 'JPY');

      // Switch to 100 EUR
      final updated = exp.copyWith(
        amount: 100,
        currencyCode: 'EUR',
        transactionAmount: 100,
        transactionCurrency: 'EUR',
      );
      await updateUseCase.execute(updated);

      final jpy = await lotRepo.getCashLotById(lotJpy.id);
      final eur = await lotRepo.getCashLotById(lotEur.id);
      // JPY lot fully restored
      expect(jpy!.remainingAmount, closeTo(5000, 1e-6));
      // EUR lot consumed by 100
      expect(eur!.remainingAmount, closeTo(100, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Edit category (metadata-only — no lot changes)
  // ---------------------------------------------------------------------------

  group('4 — edit category', () {
    test('lot state is unchanged after category edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);

      final lotBefore = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;

      final updated = exp.copyWith(category: 'Transport');
      await updateUseCase.execute(updated);

      final lotAfter = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      expect(lotAfter.remainingAmount, closeTo(lotBefore.remainingAmount, 1e-6));
    });

    test('consumption rows are not changed after category edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);

      final before = await consumptionRepo.getConsumptionsByExpenseId(exp.id);

      final updated = exp.copyWith(category: 'Transport');
      await updateUseCase.execute(updated);

      final after = await consumptionRepo.getConsumptionsByExpenseId(exp.id);
      expect(after.length, before.length);
      expect(after.every((c) => !c.isReversed), isTrue);
    });

    test('original FIFO convertedHomeAmount is preserved after category edit', () async {
      await insertLot(amount: 5000, rate: 0.035);
      final exp = await createCash(amount: 2000);
      final originalHome = exp.convertedHomeAmount;

      final updated = exp.copyWith(category: 'Transport');
      final result = await updateUseCase.execute(updated);

      expect(result.expense.convertedHomeAmount, closeTo(originalHome!, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Edit merchant (title — metadata-only)
  // ---------------------------------------------------------------------------

  group('5 — edit merchant/title', () {
    test('lot state unchanged, expense title updated', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(title: 'Sushi Bar');
      final result = await updateUseCase.execute(updated);

      expect(result.expense.title, 'Sushi Bar');
      final lot = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      expect(lot.remainingAmount, closeTo(4000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Edit notes (metadata-only)
  // ---------------------------------------------------------------------------

  group('6 — edit notes', () {
    test('lot state unchanged after note edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(note: 'Business dinner');
      final result = await updateUseCase.execute(updated);

      expect(result.expense.note, 'Business dinner');
      final lot = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      expect(lot.remainingAmount, closeTo(4000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Edit date (metadata-only)
  // ---------------------------------------------------------------------------

  group('7 — edit date', () {
    test('lot state unchanged after spentAt edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);
      final newDate = DateTime.utc(2026, 3, 15);

      final updated = exp.copyWith(spentAt: newDate);
      final result = await updateUseCase.execute(updated);

      expect(result.expense.spentAt, newDate);
      final lot = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      expect(lot.remainingAmount, closeTo(4000, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Reject: expense has active refunds
  // ---------------------------------------------------------------------------

  group('8 — reject: active refunds', () {
    test('throws hasActiveRefunds when expense has active refund', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      // Manually insert a fake active refund row.
      final dbRaw = await db.database;
      await dbRaw.insert(AppDatabase.expenseRefundsTable, {
        'id': 'refund-1',
        'trip_id': trip.id,
        'expense_id': exp.id,
        'amount': 200.0,
        'currency_code': 'JPY',
        'home_amount': null,
        'home_currency': null,
        'destination': 'cash',
        'note': null,
        'is_reversed': 0,
        'reversed_at': null,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final updated = exp.copyWith(amount: 800, transactionAmount: 800);
      expect(
        () => updateUseCase.execute(updated),
        throwsA(isA<UpdateCashExpenseException>().having(
          (e) => e.reason,
          'reason',
          UpdateCashExpenseFailureReason.hasActiveRefunds,
        )),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Reject: expense already reversed
  // ---------------------------------------------------------------------------

  group('9 — reject: expense already reversed', () {
    test('throws alreadyReversed when expense.isReversed is true', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      // Manually mark expense reversed.
      final dbRaw = await db.database;
      await dbRaw.update(
        AppDatabase.expensesTable,
        {'is_reversed': 1, 'reversed_at': DateTime.now().toUtc().toIso8601String()},
        where: 'id = ?',
        whereArgs: [exp.id],
      );

      final updated = exp.copyWith(amount: 500, transactionAmount: 500);
      expect(
        () => updateUseCase.execute(updated),
        throwsA(isA<UpdateCashExpenseException>().having(
          (e) => e.reason,
          'reason',
          UpdateCashExpenseFailureReason.alreadyReversed,
        )),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Reject: insufficient cash after edit
  // ---------------------------------------------------------------------------

  group('10 — reject: insufficient cash after edit', () {
    test('throws insufficientCash when new amount exceeds available balance', () async {
      await insertLot(amount: 2000);
      final exp = await createCash(amount: 1000);
      // After create, 1000 JPY remaining in lots

      // Trying to edit to 5000 → should fail (only 1000 available after restore)
      final updated = exp.copyWith(amount: 5000, transactionAmount: 5000);
      expect(
        () => updateUseCase.execute(updated),
        throwsA(isA<UpdateCashExpenseException>().having(
          (e) => e.reason,
          'reason',
          UpdateCashExpenseFailureReason.insufficientCash,
        )),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 11. Lot restoration correctness
  // ---------------------------------------------------------------------------

  group('11 — lot restoration correctness', () {
    test('fully-consumed lot becomes available again after edit', () async {
      // Lot is exactly consumed by the first expense
      final lot = await insertLot(amount: 1000, id: 'lot-exact');
      final exp = await createCash(amount: 1000);

      final consumed = await lotRepo.getCashLotById(lot.id);
      expect(consumed!.isFullyConsumed, isTrue);

      // Edit to 500 — lot should be partially restored
      final updated = exp.copyWith(amount: 500, transactionAmount: 500);
      await updateUseCase.execute(updated);

      final restored = await lotRepo.getCashLotById(lot.id);
      expect(restored!.remainingAmount, closeTo(500, 1e-6));
      expect(restored.isFullyConsumed, isFalse);
    });

    test('multi-lot edit: all affected lots restored then re-consumed correctly', () async {
      final t0 = DateTime.utc(2026, 1, 1);
      final t1 = DateTime.utc(2026, 1, 2);
      final lot1 = await insertLot(amount: 800, id: 'lot-a', createdAt: t0);
      final lot2 = await insertLot(amount: 1200, id: 'lot-b', createdAt: t1);
      // Expense consuming 1500 spans both lots: 800 from lot1, 700 from lot2
      final exp = await createCash(amount: 1500);

      // Edit to 600 — should only consume from lot1 (oldest)
      final updated = exp.copyWith(amount: 600, transactionAmount: 600);
      await updateUseCase.execute(updated);

      final l1 = await lotRepo.getCashLotById(lot1.id);
      final l2 = await lotRepo.getCashLotById(lot2.id);
      expect(l1!.remainingAmount, closeTo(200, 1e-6)); // 800 − 600
      expect(l2!.remainingAmount, closeTo(1200, 1e-6)); // fully restored
    });
  });

  // ---------------------------------------------------------------------------
  // 12. FIFO reallocation correctness
  // ---------------------------------------------------------------------------

  group('12 — FIFO reallocation correctness', () {
    test('new consumption rows created with correct consumed amounts', () async {
      await insertLot(amount: 5000, rate: 0.040, id: 'lot-fifo');
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(amount: 2000, transactionAmount: 2000);
      final result = await updateUseCase.execute(updated);

      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(exp.id);
      final active = consumptions.where((c) => !c.isReversed).toList();
      expect(active.length, 1);
      expect(active.first.consumedAmount, closeTo(2000, 1e-6));
      // 2000 × 0.040 = 80 SAR
      expect(result.expense.convertedHomeAmount, closeTo(80.0, 1e-6));
    });

    test('no getEffectiveCashRate usage: conversionRate comes from FIFO lot', () async {
      // Lot has effective rate 0.038; weighted-avg of raw inflows would differ.
      // The test verifies the stored rate matches the lot rate, not weighted-avg.
      await insertLot(amount: 5000, rate: 0.038, id: 'lot-rate');
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(amount: 1500, transactionAmount: 1500);
      final result = await updateUseCase.execute(updated);

      // FIFO: 1500 × 0.038 = 57 SAR
      expect(result.expense.conversionRate, closeTo(0.038, 1e-9));
      expect(result.expense.convertedHomeAmount, closeTo(57.0, 1e-6));
    });
  });

  // ---------------------------------------------------------------------------
  // 13. Rollback on failure
  // ---------------------------------------------------------------------------

  group('13 — rollback on failure', () {
    test('lot state unchanged when FIFO throws InsufficientCashException', () async {
      await insertLot(amount: 2000);
      final exp = await createCash(amount: 1000);

      final lotBefore = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;

      // Attempt fails: 5000 > 1000 available after restore
      try {
        final updated = exp.copyWith(amount: 5000, transactionAmount: 5000);
        await updateUseCase.execute(updated);
      } on UpdateCashExpenseException {
        // expected
      }

      final lotAfter = (await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY')).first;
      // Lot must be at the same state as before the failed edit
      expect(lotAfter.remainingAmount, closeTo(lotBefore.remainingAmount, 1e-6));
    });

    test('consumption rows unchanged after failed edit', () async {
      await insertLot(amount: 2000);
      final exp = await createCash(amount: 1000);

      final consumptionsBefore =
          await consumptionRepo.getConsumptionsByExpenseId(exp.id);

      try {
        final updated = exp.copyWith(amount: 5000, transactionAmount: 5000);
        await updateUseCase.execute(updated);
      } on UpdateCashExpenseException {
        // expected
      }

      final consumptionsAfter =
          await consumptionRepo.getConsumptionsByExpenseId(exp.id);
      expect(consumptionsAfter.length, consumptionsBefore.length);
      expect(consumptionsAfter.every((c) => !c.isReversed), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // 14. Audit trail correctness
  // ---------------------------------------------------------------------------

  group('14 — audit trail correctness', () {
    test('cash_transactions: old deduction reversed, new deduction recorded', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      final updated = exp.copyWith(amount: 2000, transactionAmount: 2000);
      await updateUseCase.execute(updated);

      final txns = await walletRepo.getRecentTransactionsByTrip(
        trip.id,
        includeReversed: true,
      );
      final deductions = txns
          .where((t) => t.type == CashTransactionType.cashExpenseDeduction)
          .where((t) => t.expenseId == exp.id)
          .toList();

      expect(deductions.length, 2);
      final reversed = deductions.where((t) => t.isReversed).toList();
      final active = deductions.where((t) => !t.isReversed).toList();
      expect(reversed.length, 1);
      expect(active.length, 1);
      expect(reversed.first.amount, closeTo(1000, 1e-6));
      expect(active.first.amount, closeTo(2000, 1e-6));
    });

    test('trip_cash_balances reflects net deduction after edit', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 1000);

      // Balance after create: 5000 − 1000 = 4000
      final balanceBefore = await walletRepo.getBalancesByTrip(trip.id);
      expect(
        balanceBefore.firstWhere((b) => b.currencyCode == 'JPY').balanceAmount,
        closeTo(4000, 1e-6),
      );

      // Edit to 2500; balance should be 5000 − 2500 = 2500
      final updated = exp.copyWith(amount: 2500, transactionAmount: 2500);
      await updateUseCase.execute(updated);

      final balanceAfter = await walletRepo.getBalancesByTrip(trip.id);
      expect(
        balanceAfter.firstWhere((b) => b.currencyCode == 'JPY').balanceAmount,
        closeTo(2500, 1e-6),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // 15. reverseAndDelete — lot restoration + hard delete
  // ---------------------------------------------------------------------------

  group('15 — reverseAndDelete', () {
    test('lot remaining_amount restored after delete', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);

      await updateUseCase.reverseAndDelete(exp.id);

      final openLots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(openLots.first.remainingAmount, closeTo(5000, 1e-6));
    });

    test('consumption rows are hard-deleted after reverseAndDelete', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);
      final expenseId = exp.id;

      await updateUseCase.reverseAndDelete(expenseId);

      // Rows are hard-deleted before the expense row is removed to avoid the
      // FK ON DELETE SET NULL + CHECK(expense_id IS NOT NULL) conflict.
      final consumptions =
          await consumptionRepo.getConsumptionsByExpenseId(expenseId);
      expect(consumptions, isEmpty);
    });

    test('expense row is hard-deleted', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);

      await updateUseCase.reverseAndDelete(exp.id);

      final found = await expenseRepo.getExpenseById(exp.id);
      expect(found, isNull);
    });

    test('cash_transactions deduction reversed after delete', () async {
      await insertLot(amount: 5000);
      final exp = await createCash(amount: 2000);

      await updateUseCase.reverseAndDelete(exp.id);

      final txns = await walletRepo.getRecentTransactionsByTrip(
        trip.id,
        includeReversed: true,
      );
      final deductions = txns
          .where((t) => t.type == CashTransactionType.cashExpenseDeduction)
          .toList();
      expect(deductions.isNotEmpty, isTrue);
      expect(deductions.every((t) => t.isReversed), isTrue);
    });
  });
}
