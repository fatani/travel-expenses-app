import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_not_correctable_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_withdrawal_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_consumption.dart';
import 'package:travel_expenses/features/cash_wallet/domain/correct_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
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
  late CashLotConsumptionRepository consumptionRepo;
  late ExpenseRepository expenseRepo;
  late RecordAtmWithdrawalUseCase recordUseCase;
  late AtmCorrectionService service;
  late ReverseAtmWithdrawalUseCase reverseUseCase;
  late CorrectAtmWithdrawalUseCase correctUseCase;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'atm_undo_correct');
    tripRepo = TripRepository(db);
    walletRepo = CashWalletRepository(db);
    lotRepo = CashLotRepository(db);
    consumptionRepo = CashLotConsumptionRepository(db);
    expenseRepo = ExpenseRepository(db);
    recordUseCase = RecordAtmWithdrawalUseCase(
      appDatabase: db,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      expenseRepository: expenseRepo,
    );
    service = AtmCorrectionService(
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    reverseUseCase = ReverseAtmWithdrawalUseCase(
      appDatabase: db,
      correctionService: service,
      cashWalletRepository: walletRepo,
      expenseRepository: expenseRepo,
    );
    correctUseCase = CorrectAtmWithdrawalUseCase(
      appDatabase: db,
      reverseUseCase: reverseUseCase,
      recordUseCase: recordUseCase,
    );
    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-atm-uc',
        name: 'Beijing',
        destination: 'Beijing',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  Future<AtmWithdrawalResult> recordAtm({
    double received = 1000,
    double? charged = 520,
    double? fee = 10,
  }) {
    return recordUseCase.execute(
      tripId: trip.id,
      receivedAmount: received,
      receivedCurrency: 'CNY',
      chargedAmount: charged,
      chargedCurrency: charged != null ? 'SAR' : null,
      feeAmount: fee,
      feeCurrency: fee != null ? 'SAR' : null,
      homeCurrencyCode: 'SAR',
    );
  }

  Future<double> cnyBalance() async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    final cny = balances.where((b) => b.currencyCode == 'CNY');
    return cny.isEmpty ? 0 : cny.first.balanceAmount;
  }

  /// Simulates spending [amount] CNY from [lotId] (an active consumption +
  /// reduced remaining), without the full cash-expense machinery.
  Future<void> spendFromLot(String lotId, double amount) async {
    final spender = await expenseRepo.createExpense(
      Expense.create(
        tripId: trip.id,
        title: 'Lunch',
        amount: amount,
        currencyCode: 'CNY',
        paymentMethod: 'Cash',
      ),
    );
    await consumptionRepo.insertConsumption(
      CashLotConsumption.create(
        lotId: lotId,
        consumptionType: 'cash_expense',
        expenseId: spender.id,
        consumedAmount: amount,
      ),
    );
    final lot = await lotRepo.getCashLotById(lotId);
    await lotRepo.updateLotRemainingAmount(
      lotId,
      lot!.remainingAmount - amount,
    );
  }

  // ─── AtmCorrectionService ───────────────────────────────────────────────────

  group('AtmCorrectionService', () {
    test('unused ATM with linked fee is correctable', () async {
      final r = await recordAtm();
      final status = await service.getStatus(r.cashTransaction.id);
      expect(status.canUndo, isTrue);
      expect(status.canCorrect, isTrue);
      expect(status.feeExpenseId, r.feeExpense!.id);
    });

    test('unused ATM without fee is correctable (no fee id)', () async {
      final r = await recordAtm(fee: null, charged: 510);
      final status = await service.getStatus(r.cashTransaction.id);
      expect(status.canCorrect, isTrue);
      expect(status.feeExpenseId, isNull);
    });

    test('consumed cash blocks correction and lists affected', () async {
      final r = await recordAtm();
      await spendFromLot(r.cashLot.id, 300);

      final status = await service.getStatus(r.cashTransaction.id);
      expect(status.canUndo, isFalse);
      expect(status.reasonCode, AtmCorrectionReason.cashUsed);
      expect(status.isBlockedByUsedCash, isTrue);
      expect(status.affectedTransactions, isNotEmpty);
    });

    test('legacy unlinked ATM fee in trip blocks a no-link ATM', () async {
      // A no-fee ATM, but the trip also has a legacy unlinked ATM-fee orphan.
      final r = await recordAtm(fee: null, charged: 510);
      await expenseRepo.createExpense(
        Expense.create(
          id: 'legacy-fee',
          tripId: trip.id,
          title: 'ATM Fee',
          amount: 10,
          currencyCode: 'SAR',
          paymentMethod: 'Credit Card',
          paymentChannel: 'ATM Withdrawal Fee',
          category: 'Fees',
          // No source_ref — legacy.
        ),
      );

      final status = await service.getStatus(r.cashTransaction.id);
      expect(status.canCorrect, isFalse);
      expect(status.reasonCode, AtmCorrectionReason.legacyUnlinked);
      expect(status.isUnavailable, isTrue);
    });

    test('already reversed ATM is blocked', () async {
      final r = await recordAtm();
      await reverseUseCase.execute(r.cashTransaction.id);
      final status = await service.getStatus(r.cashTransaction.id);
      expect(status.canUndo, isFalse);
      expect(status.reasonCode, AtmCorrectionReason.alreadyReversed);
    });
  });

  // ─── ReverseAtmWithdrawalUseCase ────────────────────────────────────────────

  group('Undo', () {
    test('undo ATM without fee removes the cash', () async {
      final r = await recordAtm(fee: null, charged: 510);
      expect(await cnyBalance(), closeTo(1000, 1e-6));

      await reverseUseCase.execute(r.cashTransaction.id);

      expect(await cnyBalance(), closeTo(0, 1e-6));
      final lot = await lotRepo.getCashLotById(r.cashLot.id);
      expect(lot!.isReversed, isTrue);
    });

    test('undo ATM with fee reverses the linked fee (no orphan)', () async {
      final r = await recordAtm();
      expect((await expenseRepo.getExpensesByTrip(trip.id)), hasLength(1));

      await reverseUseCase.execute(r.cashTransaction.id);

      expect(await cnyBalance(), closeTo(0, 1e-6));
      // Fee no longer active anywhere.
      expect(await expenseRepo.getExpensesByTrip(trip.id), isEmpty);
      final fee = await expenseRepo.getExpenseById(r.feeExpense!.id);
      expect(fee!.isReversed, isTrue);
    });

    test('undo blocked when cash consumed', () async {
      final r = await recordAtm();
      await spendFromLot(r.cashLot.id, 300);

      expect(
        () => reverseUseCase.execute(r.cashTransaction.id),
        throwsA(isA<AtmNotCorrectableException>()),
      );
    });

    test('undo blocked when already reversed', () async {
      final r = await recordAtm();
      await reverseUseCase.execute(r.cashTransaction.id);
      expect(
        () => reverseUseCase.execute(r.cashTransaction.id),
        throwsA(isA<AtmNotCorrectableException>()),
      );
    });
  });

  // ─── CorrectAtmWithdrawalUseCase ────────────────────────────────────────────

  group('Correct', () {
    test('correct unused ATM with fee swaps to corrected event', () async {
      final wrong = await recordAtm(received: 2000, charged: 1130, fee: 15);

      final corrected = await correctUseCase.execute(
        tripId: trip.id,
        originalAtmCashTransactionId: wrong.cashTransaction.id,
        receivedAmount: 1000,
        receivedCurrency: 'CNY',
        chargedAmount: 520,
        feeAmount: 10,
        homeCurrencyCode: 'SAR',
      );

      // Balance reflects only the corrected 1000 CNY (2000 reversed, 1000 added).
      expect(await cnyBalance(), closeTo(1000, 1e-6));

      // Old fee inactive; exactly one active fee, the corrected 10 SAR.
      final active = await expenseRepo.getExpensesByTrip(trip.id);
      expect(active, hasLength(1));
      expect(active.single.id, corrected.feeExpense!.id);
      expect(active.single.transactionAmount, closeTo(10, 1e-6));

      final oldFee = await expenseRepo.getExpenseById(wrong.feeExpense!.id);
      expect(oldFee!.isReversed, isTrue);

      // Corrected cost basis = charged - fee = 510.
      expect(corrected.cashLot.homeCurrencyAmount, closeTo(510, 1e-6));
    });

    test('correct without fee works', () async {
      final wrong = await recordAtm(received: 2000, charged: 1010, fee: null);
      final corrected = await correctUseCase.execute(
        tripId: trip.id,
        originalAtmCashTransactionId: wrong.cashTransaction.id,
        receivedAmount: 1000,
        receivedCurrency: 'CNY',
        chargedAmount: 510,
        feeAmount: null,
        homeCurrencyCode: 'SAR',
      );
      expect(await cnyBalance(), closeTo(1000, 1e-6));
      expect(corrected.feeExpense, isNull);
      expect(await expenseRepo.getExpensesByTrip(trip.id), isEmpty);
    });

    test('correct failure rolls back the original reversal', () async {
      final original = await recordAtm();

      // Invalid corrected values: fee >= charged → record step throws.
      await expectLater(
        correctUseCase.execute(
          tripId: trip.id,
          originalAtmCashTransactionId: original.cashTransaction.id,
          receivedAmount: 1000,
          receivedCurrency: 'CNY',
          chargedAmount: 10,
          feeAmount: 10,
          homeCurrencyCode: 'SAR',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Original remains fully active — nothing half-reversed.
      final status = await service.getStatus(original.cashTransaction.id);
      expect(status.canUndo, isTrue);
      expect(await cnyBalance(), closeTo(1000, 1e-6));
      final fee = await expenseRepo.getExpenseById(original.feeExpense!.id);
      expect(fee!.isReversed, isFalse);
    });

    test('correct blocked when cash consumed', () async {
      final r = await recordAtm();
      await spendFromLot(r.cashLot.id, 300);
      await expectLater(
        correctUseCase.execute(
          tripId: trip.id,
          originalAtmCashTransactionId: r.cashTransaction.id,
          receivedAmount: 1000,
          receivedCurrency: 'CNY',
          chargedAmount: 520,
          feeAmount: 10,
          homeCurrencyCode: 'SAR',
        ),
        throwsA(isA<AtmNotCorrectableException>()),
      );
    });
  });
}
