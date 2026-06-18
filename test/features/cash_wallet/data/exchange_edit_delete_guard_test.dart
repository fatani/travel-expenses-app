import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_consumption_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/currency_exchange_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_lot_fifo_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_engine.dart';
import 'package:travel_expenses/features/cash_wallet/domain/currency_exchange_result.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

/// Exchange Edit/Delete Hardening — repository (defense-in-depth) level.
///
/// updateManualCashTransaction and reverseManualCashTransaction must reject
/// exchange rows (in/out) even if a future UI re-exposes the action, while
/// ordinary manual rows remain editable and reversible.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late CashWalletRepository walletRepo;
  late RecordCurrencyExchangeUseCase exchangeUseCase;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'exchange_edit_delete_guard');
    walletRepo = CashWalletRepository(db);
    final lotRepo = CashLotRepository(db);
    exchangeUseCase = RecordCurrencyExchangeUseCase(
      appDatabase: db,
      exchangeEngine: CurrencyExchangeEngine(CashLotFifoEngine(lotRepo)),
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: CashLotConsumptionRepository(db),
      exchangeRepository: CurrencyExchangeRepository(db),
    );
    trip = await TripRepository(db).createTrip(
      Trip.create(
        id: 'trip-guard-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Shanghai',
        destination: 'Shanghai',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<double> balanceFor(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    return balances
            .where((b) => b.currencyCode == currency)
            .map((b) => b.balanceAmount)
            .firstOrNull ??
        0;
  }

  Future<CurrencyExchangeResult> seedExchange() async {
    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: 5000,
      currencyCode: 'SAR',
      homeCurrencyAmount: 5000,
      homeCurrencyCode: 'SAR',
    );
    return exchangeUseCase.execute(
      tripId: trip.id,
      fromCurrencyCode: 'SAR',
      fromAmount: 1120,
      toCurrencyCode: 'CNY',
      toAmount: 2000,
    );
  }

  // ── Test 3 — updateManualCashTransaction rejects exchange rows ─────────────
  test('updateManualCashTransaction rejects exchange in/out rows', () async {
    final result = await seedExchange();

    await expectLater(
      walletRepo.updateManualCashTransaction(
        existingTransaction: result.exchangeInTransaction,
        nextType: CashTransactionType.currencyExchangeIn,
        nextAmount: 9999,
        nextCurrencyCode: 'CNY',
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      walletRepo.updateManualCashTransaction(
        existingTransaction: result.exchangeOutTransaction,
        nextType: CashTransactionType.currencyExchangeOut,
        nextAmount: 9999,
        nextCurrencyCode: 'SAR',
      ),
      throwsA(isA<ArgumentError>()),
    );

    // Balances unchanged — no one side mutated.
    expect(await balanceFor('SAR'), closeTo(3880, 0.000001));
    expect(await balanceFor('CNY'), closeTo(2000, 0.000001));
  });

  // ── Test 4 — reverseManualCashTransaction rejects exchange rows ────────────
  test('reverseManualCashTransaction rejects exchange in/out rows', () async {
    final result = await seedExchange();

    await expectLater(
      walletRepo.reverseManualCashTransaction(
        transaction: result.exchangeInTransaction,
      ),
      throwsA(isA<ArgumentError>()),
    );
    await expectLater(
      walletRepo.reverseManualCashTransaction(
        transaction: result.exchangeOutTransaction,
      ),
      throwsA(isA<ArgumentError>()),
    );

    // Both sides intact; balance conservation preserved.
    expect(await balanceFor('SAR'), closeTo(3880, 0.000001));
    expect(await balanceFor('CNY'), closeTo(2000, 0.000001));
  });

  // ── Test 5 & 6 (repo) — ordinary manual rows stay editable & reversible ────
  test('manual adjustment remains editable and reversible', () async {
    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.manualAdjustment,
      amount: 300,
      currencyCode: 'CNY',
    );
    final adjustment = (await walletRepo.getRecentTransactionsByTrip(trip.id))
        .firstWhere((t) => t.type == CashTransactionType.manualAdjustment);

    // Editable.
    await walletRepo.updateManualCashTransaction(
      existingTransaction: adjustment,
      nextType: CashTransactionType.manualAdjustment,
      nextAmount: 450,
      nextCurrencyCode: 'CNY',
    );
    expect(await balanceFor('CNY'), closeTo(450, 0.000001));

    // Reversible.
    final updated = (await walletRepo.getRecentTransactionsByTrip(trip.id))
        .firstWhere((t) =>
            t.type == CashTransactionType.manualAdjustment && !t.isReversed);
    await walletRepo.reverseManualCashTransaction(transaction: updated);
    expect(await balanceFor('CNY'), closeTo(0, 0.000001));
  });
}
