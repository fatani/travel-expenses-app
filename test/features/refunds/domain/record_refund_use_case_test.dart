import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/over_refund_exception.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late TripRepository tripRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late ExpenseRefundRepository refundRepo;
  late ExpenseRepository expenseRepo;
  late RecordRefundUseCase useCase;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'record_refund');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    refundRepo = ExpenseRefundRepository(db);
    expenseRepo = ExpenseRepository(db);
    useCase = RecordRefundUseCase(
      appDatabase: db,
      refundEngine: const RefundInheritanceEngine(),
      refundRepository: refundRepo,
      lotRepository: lotRepo,
      cashWalletRepository: walletRepo,
    );
    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-refund',
        name: 'Refund Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // Helper: create a cash expense linked to the trip
  Future<Expense> createCashExpense({
    double amount = 1000,
    String currency = 'JPY',
    double? convertedHomeAmount,
    String homeCurrency = 'SAR',
  }) {
    return expenseRepo.createExpense(
      Expense.create(
        tripId: trip.id,
        title: 'Test Expense',
        amount: amount,
        currencyCode: currency,
        transactionAmount: amount,
        transactionCurrency: currency,
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        category: 'Food',
        convertedHomeAmount: convertedHomeAmount,
        homeCurrency: convertedHomeAmount != null ? homeCurrency : null,
      ),
    );
  }

  Future<double> walletBalance(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    final b = balances.where((b) => b.currencyCode == currency);
    return b.isEmpty ? 0.0 : b.first.balanceAmount;
  }

  // ─── 1. Cash refund creates returned Cash Lot ─────────────────────────────

  group('1 — cash refund creates Cash Lot', () {
    test('exactly one cash_lot row with correct fields', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashLot, isNotNull);
      expect(result.cashLot!.originalAmount, closeTo(500, 1e-6));
      expect(result.cashLot!.remainingAmount, closeTo(500, 1e-6));
      expect(result.cashLot!.currencyCode, 'JPY');
      expect(result.cashLot!.sourceType, 'cash_refund');
      expect(result.cashLot!.sourceRefType, 'expense_refund');

      final dbLot = await lotRepo.getCashLotById(result.cashLot!.id);
      expect(dbLot, isNotNull);
    });
  });

  // ─── 2. Cash refund sets returned_lot_id on expense_refunds ──────────────

  group('2 — returned_lot_id set on refund row', () {
    test('refund.returnedLotId == cashLot.id', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.refund.returnedLotId, result.cashLot!.id);

      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      expect(refunds.first.returnedLotId, result.cashLot!.id);
    });
  });

  // ─── 3. Cash lot source_ref_id points to refund.id ───────────────────────

  group('3 — lot.sourceRefId == refund.id', () {
    test('returned_lot.source_ref_id = refund.id', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashLot!.sourceRefId, result.refund.id);

      final dbLot = await lotRepo.getCashLotById(result.cashLot!.id);
      expect(dbLot!.sourceRefId, result.refund.id);
    });
  });

  // ─── 4. Cash refund creates cash_transaction ──────────────────────────────

  group('4 — cash_transaction created', () {
    test('cashRefund transaction with correct type and currency', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashTransaction, isNotNull);
      expect(result.cashTransaction!.amount, closeTo(500, 1e-6));
      expect(result.cashTransaction!.currencyCode, 'JPY');
    });

    test('cash_transaction.lotId == returned lot id', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashTransaction!.lotId, result.cashLot!.id);
    });
  });

  // ─── 5. Cash refund increases trip_cash_balances ──────────────────────────

  group('5 — cash balance increases', () {
    test('JPY balance increases by refundAmount', () async {
      await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(await walletBalance('JPY'), closeTo(500, 1e-4));
    });

    test('balance accumulates with multiple refunds', () async {
      await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );
      await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 300,
        refundCurrency: 'JPY',
        homeAmount: 8.1,
        homeCurrency: 'SAR',
      );

      expect(await walletBalance('JPY'), closeTo(800, 1e-4));
    });
  });

  // ─── 6. Cash refund effective_rate = homeAmount / amount ─────────────────

  group('6 — effective_rate', () {
    test('effectiveRate = homeAmount / refundAmount', () async {
      // 500 JPY @ 13.5 SAR → rate = 0.027
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashLot!.effectiveRate, closeTo(0.027, 1e-9));
    });

    test('lot homeCurrencyAmount equals homeAmount', () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashLot!.homeCurrencyAmount, closeTo(13.5, 1e-9));
      expect(result.cashLot!.homeCurrencyCode, 'SAR');
    });
  });

  // ─── 7. Partial linked refund allowed ────────────────────────────────────

  group('7 — partial linked refund accepted', () {
    test('partial refund (50% of expense) succeeds', () async {
      final expense = await createCashExpense(
        amount: 1000,
        convertedHomeAmount: 27.0,
      );

      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5, // half of 27
        homeCurrency: 'SAR',
        linkedExpense: expense,
      );

      expect(result.refund.amount, closeTo(500, 1e-6));
      expect(result.refund.expenseId, expense.id);
    });
  });

  // ─── 8. Over-refund rejected ─────────────────────────────────────────────

  group('8 — over-refund rejected', () {
    test('throws OverRefundException when home total exceeds expense', () async {
      final expense = await createCashExpense(
        amount: 1000,
        convertedHomeAmount: 27.0,
      );

      expect(
        () => useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          expenseId: expense.id,
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: 30.0, // > 27 SAR limit
          homeCurrency: 'SAR',
          linkedExpense: expense,
        ),
        throwsA(isA<OverRefundException>()),
      );
    });

    test('second refund that exceeds total is rejected', () async {
      final expense = await createCashExpense(
        amount: 1000,
        convertedHomeAmount: 27.0,
      );

      // First refund: 20 SAR (within limit)
      await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 740,
        refundCurrency: 'JPY',
        homeAmount: 20.0,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      );

      // Second refund: 10 SAR (total would be 30 > 27)
      expect(
        () => useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          expenseId: expense.id,
          refundAmount: 370,
          refundCurrency: 'JPY',
          homeAmount: 10.0,
          homeCurrency: 'SAR',
          linkedExpense: expense,
        ),
        throwsA(isA<OverRefundException>()),
      );
    });
  });

  // ─── 9. Unlinked cash refund requires homeAmount/homeCurrency ─────────────

  group('9 — unlinked cash refund requires home basis', () {
    test('throws ArgumentError when homeAmount is null for unlinked cash', () {
      expect(
        () => useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          // expenseId: null — unlinked
          refundAmount: 500,
          refundCurrency: 'JPY',
          // homeAmount: null — not provided
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when homeAmount provided but homeCurrency missing',
        () {
      expect(
        () => useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          refundAmount: 500,
          refundCurrency: 'JPY',
          homeAmount: 13.5,
          // homeCurrency: null — missing
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─── 10. Unlinked cash refund with basis accepted ────────────────────────

  group('10 — unlinked cash refund with basis', () {
    test('unlinked cash refund with homeAmount and homeCurrency succeeds',
        () async {
      final result = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        // expenseId: null
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.refund.expenseId, isNull);
      expect(result.cashLot, isNotNull);
      expect(result.cashLot!.homeCurrencyAmount, closeTo(13.5, 1e-9));
      expect(await walletBalance('JPY'), closeTo(500, 1e-4));
    });
  });

  // ─── 11. Card refund creates no Cash Lot ─────────────────────────────────

  group('11 — card refund creates no Cash Lot', () {
    test('cashLot is null for card refund', () async {
      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(result.cashLot, isNull);
      expect(result.cashTransaction, isNull);
    });

    test('no lot row in DB for card refund', () async {
      await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots, isEmpty);
    });

    test('expense_refunds row created for card refund', () async {
      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      expect(refunds, hasLength(1));
      expect(refunds.first.id, result.refund.id);
    });
  });

  // ─── 12. Card refund does not affect cash balance ─────────────────────────

  group('12 — card refund does not affect cash balance', () {
    test('JPY balance remains 0 after card refund', () async {
      await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        refundAmount: 500,
        refundCurrency: 'JPY',
        homeAmount: 13.5,
        homeCurrency: 'SAR',
      );

      expect(await walletBalance('JPY'), closeTo(0, 1e-6));
    });
  });

  // ─── 13. Card refund can be unlinked with null homeAmount ─────────────────

  group('13 — card refund accepts null homeAmount', () {
    test('unlinked card refund with null homeAmount succeeds', () async {
      final result = await useCase.execute(
        destination: RefundDestination.card,
        tripId: trip.id,
        // expenseId: null — unlinked
        refundAmount: 500,
        refundCurrency: 'JPY',
        // homeAmount: null — allowed for card
      );

      expect(result.refund.homeAmount, isNull);
      expect(result.refund.returnedLotId, isNull);
    });
  });

  // ─── 14. Reversed refunds excluded from over-refund total ────────────────

  group('14 — reversed refunds excluded from over-refund check', () {
    test('after reversing first refund, second refund in the same range is allowed',
        () async {
      final expense = await createCashExpense(
        amount: 1000,
        convertedHomeAmount: 27.0,
      );

      // First refund: 20 SAR
      final firstResult = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 740,
        refundCurrency: 'JPY',
        homeAmount: 20.0,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      );

      // Reverse the first refund using existing repository method
      await refundRepo.reverseCashRefund(firstResult.refund);

      // Now a second refund of 25 SAR should succeed (reversed refund is excluded)
      final secondResult = await useCase.execute(
        destination: RefundDestination.cash,
        tripId: trip.id,
        expenseId: expense.id,
        refundAmount: 925,
        refundCurrency: 'JPY',
        homeAmount: 25.0,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      );

      expect(secondResult.refund.homeAmount, closeTo(25.0, 1e-9));
    });
  });

  // ─── 15. Atomic rollback on cash refund write failure ────────────────────

  group('15 — atomic rollback', () {
    test('no lot or refund row after ArgumentError (invalid amount)', () async {
      try {
        await useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          refundAmount: -1, // invalid
          refundCurrency: 'JPY',
          homeAmount: 13.5,
          homeCurrency: 'SAR',
        );
      } on ArgumentError {/* expected */}

      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots, isEmpty);

      final refunds = await refundRepo.getActiveRefundsByTrip(trip.id);
      expect(refunds, isEmpty);
    });

    test('balance unchanged after over-refund failure', () async {
      final expense = await createCashExpense(
        amount: 1000,
        convertedHomeAmount: 27.0,
      );

      try {
        await useCase.execute(
          destination: RefundDestination.cash,
          tripId: trip.id,
          expenseId: expense.id,
          refundAmount: 1000,
          refundCurrency: 'JPY',
          homeAmount: 50.0, // > 27 limit
          homeCurrency: 'SAR',
          linkedExpense: expense,
        );
      } catch (_) {/* expected */}

      expect(await walletBalance('JPY'), closeTo(0, 1e-6));

      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots, isEmpty);
    });
  });
}
