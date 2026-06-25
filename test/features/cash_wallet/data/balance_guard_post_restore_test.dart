// Tests: v1.0.1 balance-level guard prevents negative trip_cash_balances after
// Backup Format v1 restore.
//
// Restore divergence: lots are recreated with remaining_amount = original_amount
// while trip_cash_balances is correctly recomputed from cash_transactions.
// The guard (in CashWalletRepository) must block any outflow that would push
// the true balance below zero — even when FIFO sees sufficient lot remaining.
//
// Simulating the divergence in tests:
//   1. Record real inflows so lots and balance both start at [X].
//   2. Directly lower trip_cash_balances.balance_amount to [Y < X] to represent
//      spending that happened before the backup (the lot is untouched, matching
//      the backfill behaviour of CashLotBackfill.backfillUnlinkedInflowLots).
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/atm_not_correctable_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_correction_service.dart';
import 'package:travel_expenses/features/cash_wallet/domain/exchange_not_correctable_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/insufficient_cash_exception.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/cash_wallet/domain/reverse_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/record_cash_expense_use_case.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDb;
  late TripRepository tripRepo;
  late CashWalletRepository walletRepo;
  late CashLotRepository lotRepo;
  late CashLotConsumptionRepository consumptionRepo;
  late CurrencyExchangeRepository exchangeRepo;
  late ExpenseRepository expenseRepo;
  late CashLotFifoEngine fifo;
  late RecordCashExpenseUseCase recordCashExpense;
  late RecordAtmWithdrawalUseCase recordAtm;
  late AtmCorrectionService atmService;
  late ReverseAtmWithdrawalUseCase reverseAtm;
  late RecordCurrencyExchangeUseCase recordExchange;
  late ExchangeCorrectionService exchangeService;
  late ReverseCurrencyExchangeUseCase reverseExchange;
  late Trip trip;

  setUp(() async {
    appDb = createIsolatedAppDatabase(prefix: 'balance_guard');
    tripRepo = TripRepository(appDb);
    walletRepo = CashWalletRepository(appDb);
    lotRepo = CashLotRepository(appDb);
    consumptionRepo = CashLotConsumptionRepository(appDb);
    exchangeRepo = CurrencyExchangeRepository(appDb);
    expenseRepo = ExpenseRepository(appDb);
    fifo = CashLotFifoEngine(lotRepo);

    recordCashExpense = RecordCashExpenseUseCase(
      appDatabase: appDb,
      expenseRepository: expenseRepo,
      cashWalletRepository: walletRepo,
      fifoEngine: fifo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
    );
    recordAtm = RecordAtmWithdrawalUseCase(
      appDatabase: appDb,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      expenseRepository: expenseRepo,
    );
    atmService = AtmCorrectionService(
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    reverseAtm = ReverseAtmWithdrawalUseCase(
      appDatabase: appDb,
      correctionService: atmService,
      cashWalletRepository: walletRepo,
      expenseRepository: expenseRepo,
    );

    final exchangeEngine = CurrencyExchangeEngine(fifo);
    recordExchange = RecordCurrencyExchangeUseCase(
      appDatabase: appDb,
      exchangeEngine: exchangeEngine,
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
    );
    exchangeService = ExchangeCorrectionService(
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      expenseRepository: expenseRepo,
    );
    reverseExchange = ReverseCurrencyExchangeUseCase(
      appDatabase: appDb,
      correctionService: exchangeService,
      exchangeRepository: exchangeRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      cashWalletRepository: walletRepo,
    );

    trip = await tripRepo.createTrip(
      Trip.create(
        id: 'trip-guard-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Guard Trip',
        destination: 'Japan',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => appDb.close());

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Directly sets [trip_cash_balances.balance_amount] for [currency] to
  /// [amount], simulating the divergence that occurs after a v1 backup restore:
  /// the balance is recomputed from transactions (correct) while lots retain
  /// their original remaining_amount (overstated).
  Future<void> forceBalance(String currency, double amount) async {
    final db = await appDb.database;
    await db.update(
      AppDatabase.tripCashBalancesTable,
      {'balance_amount': amount},
      where: 'trip_id = ? AND currency_code = ?',
      whereArgs: [trip.id, currency.toUpperCase()],
    );
  }

  Future<double> balanceOf(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    for (final b in balances) {
      if (b.currencyCode == currency.toUpperCase()) return b.balanceAmount;
    }
    return 0;
  }

  Future<void> addJpy(double amount) => walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: amount,
        currencyCode: 'JPY',
      );

  // ── A: Post-restore cash expense overdraft is blocked ──────────────────────

  group('A — post-restore cash expense overdraft blocked', () {
    test('FIFO approves but balance guard rejects; no expense or balance change',
        () async {
      // 1. Normal inflow — lot remaining = 1000, balance = 1000.
      await addJpy(1000);
      expect(await balanceOf('JPY'), closeTo(1000, 1e-6));

      // 2. Simulate restore divergence: balance lowered to 400 (600 spent pre-backup).
      //    Lot still shows remaining = 1000 (backfill behaviour).
      await forceBalance('JPY', 400);
      expect(await balanceOf('JPY'), closeTo(400, 1e-6));

      // Confirm lot remaining is still 1000 (FIFO would approve 500).
      final lots = await lotRepo.getOpenLotsForCurrency(trip.id, 'JPY');
      expect(lots.first.remainingAmount, closeTo(1000, 1e-6));

      // 3. Attempt cash expense of 500 — exceeds true balance of 400.
      await expectLater(
        () => recordCashExpense.execute(
          _cashExpense(tripId: trip.id, amount: 500, currency: 'JPY'),
        ),
        throwsA(isA<InsufficientCashException>()),
      );

      // 4. Balance unchanged; expense not created.
      expect(await balanceOf('JPY'), closeTo(400, 1e-6));
      expect(await expenseRepo.getExpensesByTrip(trip.id), isEmpty);
    });
  });

  // ── B: Post-restore cash expense within true balance succeeds ──────────────

  group('B — post-restore cash expense within true balance succeeds', () {
    test('expense within true balance commits and decrements balance', () async {
      await addJpy(1000);
      await forceBalance('JPY', 400);

      // 300 is within the true balance of 400.
      await recordCashExpense.execute(
        _cashExpense(tripId: trip.id, amount: 300, currency: 'JPY'),
      );

      expect(await balanceOf('JPY'), closeTo(100, 1e-6));
      expect(await expenseRepo.getExpensesByTrip(trip.id), hasLength(1));
    });
  });

  // ── C: Post-restore ATM undo is blocked when ATM cash was partially spent ──

  group('C — post-restore ATM undo blocked when cash was spent before backup',
      () {
    test(
        'undo gate (lot check) passes but balance guard rejects; '
        'ATM state and balance unchanged', () async {
      // 1. Record ATM withdrawal: lot remaining = 1000, balance = 1000.
      final atm = await recordAtm.execute(
        tripId: trip.id,
        receivedAmount: 1000,
        receivedCurrency: 'JPY',
      );
      expect(await balanceOf('JPY'), closeTo(1000, 1e-6));

      // 2. Simulate restore divergence: balance = 600 (400 spent pre-backup).
      //    ATM lot still shows remaining = 1000 with no active consumptions.
      await forceBalance('JPY', 600);

      // Confirm the ATM correction service says canUndo=true (lot check passes).
      final status = await atmService.getStatus(atm.cashTransaction.id);
      expect(status.canUndo, isTrue,
          reason: 'lot remaining == original and no consumptions → gate passes');

      // 3. Attempt ATM undo — balance guard fires inside the transaction.
      await expectLater(
        () => reverseAtm.execute(atm.cashTransaction.id),
        throwsA(isA<AtmNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          AtmCorrectionReason.cashUsed,
        )),
      );

      // 4. Balance unchanged; ATM cash transaction still active.
      expect(await balanceOf('JPY'), closeTo(600, 1e-6));
      final cashTx = await walletRepo.getCashTransactionById(
        atm.cashTransaction.id,
      );
      expect(cashTx!.isReversed, isFalse);
    });
  });

  // ── D: Normal ATM undo still works when cash was not spent ─────────────────

  group('D — normal ATM undo succeeds when cash was not spent', () {
    test('undo fully reverses ATM lot and balance', () async {
      final atm = await recordAtm.execute(
        tripId: trip.id,
        receivedAmount: 1000,
        receivedCurrency: 'JPY',
      );
      expect(await balanceOf('JPY'), closeTo(1000, 1e-6));

      // No forceBalance call — balance and lot remaining are in sync.
      await reverseAtm.execute(atm.cashTransaction.id);

      expect(await balanceOf('JPY'), closeTo(0, 1e-6));
      final lot = await lotRepo.getCashLotById(atm.cashLot.id);
      expect(lot!.isReversed, isTrue);
      final cashTx =
          await walletRepo.getCashTransactionById(atm.cashTransaction.id);
      expect(cashTx!.isReversed, isTrue);
    });
  });

  // ── E: Post-restore exchange-out blocked when source balance insufficient ──

  group('E — post-restore exchange-out blocked by balance guard', () {
    test(
        'FIFO approves source lots but balance guard rejects; '
        'no exchange rows written', () async {
      // 1. Add 1000 JPY — lot remaining = 1000, balance = 1000.
      await addJpy(1000);

      // 2. Simulate restore: balance = 400 (600 spent pre-backup).
      await forceBalance('JPY', 400);

      // 3. Attempt exchange of 600 JPY → CNY (more than true JPY balance).
      await expectLater(
        () => recordExchange.execute(
          tripId: trip.id,
          fromCurrencyCode: 'JPY',
          fromAmount: 600,
          toCurrencyCode: 'CNY',
          toAmount: 86,
        ),
        throwsA(isA<InsufficientCashException>()),
      );

      // 4. Balances unchanged; no exchange row written.
      expect(await balanceOf('JPY'), closeTo(400, 1e-6));
      expect(await balanceOf('CNY'), closeTo(0, 1e-6));
    });
  });

  // ── F: Post-restore exchange undo blocked when destination cash was spent ──

  group('F — post-restore exchange undo blocked when destination cash was spent',
      () {
    test(
        'exchange undo gate (lot check) passes but balance guard rejects; '
        'exchange and balances unchanged', () async {
      // 1. Add 5000 JPY, exchange 5000 JPY → 720 CNY.
      await addJpy(5000);
      final result = await recordExchange.execute(
        tripId: trip.id,
        fromCurrencyCode: 'JPY',
        fromAmount: 5000,
        toCurrencyCode: 'CNY',
        toAmount: 720,
      );
      expect(await balanceOf('JPY'), closeTo(0, 1e-6));
      expect(await balanceOf('CNY'), closeTo(720, 1e-6));

      // 2. Simulate restore divergence: CNY balance = 300 (420 spent pre-backup).
      //    Destination lot still shows remaining = 720, no consumptions of the lot.
      await forceBalance('CNY', 300);

      // Confirm exchange correction service says canUndo=true (lot check passes).
      final status = await exchangeService.getStatus(result.exchange.id);
      expect(status.canUndo, isTrue,
          reason:
              'dest lot remaining == original and no consumptions → gate passes');

      // 3. Attempt exchange undo — balance guard fires when reversing the
      //    exchange_in transaction (which decrements CNY by 720).
      await expectLater(
        () => reverseExchange.execute(result.exchange.id),
        throwsA(isA<ExchangeNotCorrectableException>().having(
          (e) => e.reason,
          'reason',
          ExchangeCorrectionReason.destinationCashUsed,
        )),
      );

      // 4. CNY balance unchanged; exchange row still active.
      expect(await balanceOf('CNY'), closeTo(300, 1e-6));
      final exchange =
          await exchangeRepo.getExchangeById(result.exchange.id);
      expect(exchange!.isReversed, isFalse);

      // 5. JPY balance also unchanged (no partial reverse committed).
      expect(await balanceOf('JPY'), closeTo(0, 1e-6));
    });
  });
}

// ── Test helpers ─────────────────────────────────────────────────────────────

Expense _cashExpense({
  required String tripId,
  required double amount,
  required String currency,
}) {
  return Expense.create(
    tripId: tripId,
    title: 'Test cash expense',
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
    spentAt: DateTime(2026, 6, 25),
  );
}
