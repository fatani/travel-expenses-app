import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
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
  late ExpenseRepository expenseRepo;
  late RecordAtmWithdrawalUseCase useCase;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'record_atm_withdrawal');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    expenseRepo = ExpenseRepository(db);
    useCase = RecordAtmWithdrawalUseCase(
      appDatabase: db,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      expenseRepository: expenseRepo,
    );
    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-atm',
        name: 'ATM Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // ─── 1. ATM withdrawal creates a Cash Lot ──────────────────────────────────

  group('1 — creates Cash Lot', () {
    test('execute creates exactly one cash_lot row', () async {
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
      );

      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots, hasLength(1));
      expect(lots.first.originalAmount, closeTo(10000, 1e-6));
      expect(lots.first.remainingAmount, closeTo(10000, 1e-6));
      expect(lots.first.currencyCode, 'JPY');
    });
  });

  // ─── 2. source_type = 'atm_withdrawal' ────────────────────────────────────

  group('2 — Cash Lot source_type', () {
    test('source_type is atm_withdrawal', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 5000,
        receivedCurrency: 'JPY',
      );
      expect(result.cashLot.sourceType, 'atm_withdrawal');
    });
  });

  // ─── 3. source_ref_type = 'cash_transaction' ──────────────────────────────

  group('3 — Cash Lot source_ref_type', () {
    test('source_ref_type is cash_transaction', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 5000,
        receivedCurrency: 'JPY',
      );
      expect(result.cashLot.sourceRefType, 'cash_transaction');
    });
  });

  // ─── 4. source_ref_id points to cash_transaction.id ──────────────────────

  group('4 — source_ref_id matches cash_transaction.id', () {
    test('lot.sourceRefId == cashTransaction.id', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 8000,
        receivedCurrency: 'JPY',
      );
      expect(result.cashLot.sourceRefId, result.cashTransaction.id);
    });

    test('source_ref_id persisted to DB', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 8000,
        receivedCurrency: 'JPY',
      );
      final dbLot = await lotRepo.getCashLotById(result.cashLot.id);
      expect(dbLot!.sourceRefId, result.cashTransaction.id);
    });
  });

  // ─── 5. cash_transactions.lot_id points to Cash Lot ──────────────────────

  group('5 — cash_transaction.lot_id', () {
    test('cash_transaction.lotId == cashLot.id', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 6000,
        receivedCurrency: 'JPY',
      );
      expect(result.cashTransaction.lotId, result.cashLot.id);
    });

    test('cash_transaction type is atmWithdrawal', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 6000,
        receivedCurrency: 'JPY',
      );
      expect(result.cashTransaction.type, CashTransactionType.atmWithdrawal);
    });
  });

  // ─── 6. trip_cash_balances increases by receivedAmount ────────────────────

  group('6 — balance increases by receivedAmount', () {
    test('balance increases by receivedAmount after withdrawal', () async {
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 12000,
        receivedCurrency: 'JPY',
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final jpyBalance = balances
          .firstWhere((b) => b.currencyCode == 'JPY')
          .balanceAmount;
      expect(jpyBalance, closeTo(12000, 1e-4));
    });

    test('balance accumulates across multiple withdrawals', () async {
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 5000,
        receivedCurrency: 'JPY',
      );
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 3000,
        receivedCurrency: 'JPY',
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final jpyBalance = balances
          .firstWhere((b) => b.currencyCode == 'JPY')
          .balanceAmount;
      expect(jpyBalance, closeTo(8000, 1e-4));
    });
  });

  // ─── 7. Cost basis excludes fee ───────────────────────────────────────────

  group('7 — cost basis excludes fee', () {
    test('effectiveRate = (chargedAmount - feeAmount) / receivedAmount', () async {
      // Received: 10,000 JPY. Charged: 275 SAR. Fee: 5 SAR.
      // cashPortion = 270 SAR. effectiveRate = 270 / 10000 = 0.027
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      expect(result.cashLot.homeCurrencyAmount, closeTo(270.0, 1e-6));
      expect(result.cashLot.homeCurrencyCode, 'SAR');
      expect(result.cashLot.effectiveRate, closeTo(0.027, 1e-9));
    });

    test('lot homeCurrencyAmount equals chargedAmount when fee is zero', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 280,
        chargedCurrency: 'SAR',
      );

      expect(result.cashLot.homeCurrencyAmount, closeTo(280.0, 1e-6));
      expect(result.cashLot.effectiveRate, closeTo(0.028, 1e-9));
    });
  });

  // ─── 8. Fee creates Card Expense ──────────────────────────────────────────

  group('8 — fee creates Card Expense', () {
    test('feeExpense is non-null when feeAmount > 0', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      expect(result.feeExpense, isNotNull);
      expect(result.feeExpense!.transactionAmount, closeTo(5.0, 1e-6));
      expect(result.feeExpense!.transactionCurrency, 'SAR');
    });

    test('fee expense persisted to expenses table', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      final expenses = await expenseRepo.getExpensesByTrip(trip.id);
      expect(expenses, hasLength(1));
      expect(expenses.first.id, result.feeExpense!.id);
    });
  });

  // ─── 9. Fee does not affect cash balance ──────────────────────────────────

  group('9 — fee does not affect cash balance', () {
    test('JPY balance equals receivedAmount regardless of fee', () async {
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final jpyBalance = balances
          .firstWhere((b) => b.currencyCode == 'JPY')
          .balanceAmount;
      // Balance is receivedAmount (10,000 JPY), not reduced by fee
      expect(jpyBalance, closeTo(10000, 1e-4));
    });

    test('SAR balance is NOT modified by the fee expense', () async {
      await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      final sarEntry = balances.where((b) => b.currencyCode == 'SAR');
      // SAR is not a tracked cash currency here — no SAR balance row
      expect(sarEntry, isEmpty);
    });
  });

  // ─── 10. Fee uses payment_channel = 'ATM Withdrawal Fee' ─────────────────

  group('10 — fee payment_channel', () {
    test("fee expense payment_channel is 'ATM Withdrawal Fee'", () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      expect(result.feeExpense!.paymentChannel, 'ATM Withdrawal Fee');
    });
  });

  // ─── 11. Fee uses fundingCardId when provided ─────────────────────────────

  group('11 — fee uses fundingCardId', () {
    test('fee expense cardProfileId matches fundingCardId', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
        fundingCardId: 42,
      );

      expect(result.feeExpense!.cardProfileId, 42);
    });

    test('fee expense cardProfileId is null when fundingCardId not provided',
        () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        chargedAmount: 275,
        chargedCurrency: 'SAR',
        feeAmount: 5,
        feeCurrency: 'SAR',
      );

      expect(result.feeExpense!.cardProfileId, isNull);
    });
  });

  // ─── 12. Fee = 0 creates no expense ──────────────────────────────────────

  group('12 — fee = 0 or null → no expense', () {
    test('feeExpense is null when feeAmount is null', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 5000,
        receivedCurrency: 'JPY',
      );
      expect(result.feeExpense, isNull);
    });

    test('feeExpense is null when feeAmount = 0', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 5000,
        receivedCurrency: 'JPY',
        chargedAmount: 130,
        chargedCurrency: 'SAR',
        feeAmount: 0,
      );
      expect(result.feeExpense, isNull);

      final expenses = await expenseRepo.getExpensesByTrip(trip.id);
      expect(expenses, isEmpty);
    });
  });

  // ─── 13. chargedAmount null → lot without cost basis ─────────────────────

  group('13 — null chargedAmount → lot without cost basis', () {
    test('lot has null homeCurrencyAmount and null effectiveRate', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 10000,
        receivedCurrency: 'JPY',
        // chargedAmount intentionally omitted
      );

      expect(result.cashLot.homeCurrencyAmount, isNull);
      expect(result.cashLot.homeCurrencyCode, isNull);
      expect(result.cashLot.effectiveRate, isNull);
    });

    test('lot still has correct receivedAmount and currency', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 7000,
        receivedCurrency: 'JPY',
      );

      expect(result.cashLot.originalAmount, closeTo(7000, 1e-6));
      expect(result.cashLot.currencyCode, 'JPY');
    });
  });

  // ─── 14. invalid feeAmount >= chargedAmount fails ─────────────────────────

  group('14 — fee >= chargedAmount throws ArgumentError', () {
    test('feeAmount == chargedAmount throws', () {
      expect(
        () => useCase.execute(
          tripId: trip.id,
          receivedAmount: 10000,
          receivedCurrency: 'JPY',
          chargedAmount: 275,
          chargedCurrency: 'SAR',
          feeAmount: 275, // equal → invalid
          feeCurrency: 'SAR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('feeAmount > chargedAmount throws', () {
      expect(
        () => useCase.execute(
          tripId: trip.id,
          receivedAmount: 10000,
          receivedCurrency: 'JPY',
          chargedAmount: 275,
          chargedCurrency: 'SAR',
          feeAmount: 300, // greater → invalid
          feeCurrency: 'SAR',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('negative feeAmount throws', () {
      expect(
        () => useCase.execute(
          tripId: trip.id,
          receivedAmount: 10000,
          receivedCurrency: 'JPY',
          chargedAmount: 275,
          chargedCurrency: 'SAR',
          feeAmount: -1,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ─── 15. Atomic rollback on failure ──────────────────────────────────────

  group('15 — atomic rollback', () {
    test('no lot remains when receivedAmount is invalid (throws before txn)',
        () async {
      try {
        await useCase.execute(
          tripId: trip.id,
          receivedAmount: -1, // invalid
          receivedCurrency: 'JPY',
        );
      } on ArgumentError {
        // expected
      }

      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots, isEmpty);
    });

    test('no cash_transaction row written on validation error', () async {
      try {
        await useCase.execute(
          tripId: trip.id,
          receivedAmount: 10000,
          receivedCurrency: 'JPY',
          chargedAmount: 100,
          chargedCurrency: 'SAR',
          feeAmount: 200, // fee > charged → throws before transaction
        );
      } on ArgumentError {
        // expected
      }

      final txns = await walletRepo.getRecentTransactionsByTrip(trip.id);
      expect(txns, isEmpty);
    });

    test('balance unchanged after validation failure', () async {
      try {
        await useCase.execute(
          tripId: trip.id,
          receivedAmount: 0, // invalid
          receivedCurrency: 'JPY',
        );
      } on ArgumentError {
        // expected
      }

      final balances = await walletRepo.getBalancesByTrip(trip.id);
      expect(balances.where((b) => b.currencyCode == 'JPY'), isEmpty);
    });
  });
}
