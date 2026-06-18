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
import 'package:travel_expenses/features/cash_wallet/domain/record_currency_exchange_use_case.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

/// Exchange Integrity Fix — proves the orphan-inflow hole is closed and the
/// legitimate exchange path still satisfies the Financial Core invariants and
/// balance conservation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late CashWalletRepository walletRepo;
  late RecordCurrencyExchangeUseCase exchangeUseCase;
  late Trip trip;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'exchange_integrity');
    walletRepo = CashWalletRepository(appDatabase);
    final lotRepo = CashLotRepository(appDatabase);
    final consumptionRepo = CashLotConsumptionRepository(appDatabase);
    final exchangeRepo = CurrencyExchangeRepository(appDatabase);
    exchangeUseCase = RecordCurrencyExchangeUseCase(
      appDatabase: appDatabase,
      exchangeEngine: CurrencyExchangeEngine(CashLotFifoEngine(lotRepo)),
      cashWalletRepository: walletRepo,
      lotRepository: lotRepo,
      consumptionRepository: consumptionRepo,
      exchangeRepository: exchangeRepo,
    );
    trip = await TripRepository(appDatabase).createTrip(
      Trip.create(
        id: 'trip-exchange-integrity-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Bangkok',
        destination: 'Bangkok',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<double> balanceFor(String currency) async {
    final balances = await walletRepo.getBalancesByTrip(trip.id);
    return balances
            .where((b) => b.currencyCode == currency)
            .map((b) => b.balanceAmount)
            .firstOrNull ??
        0;
  }

  // ── Test 2 — Exchange Office + valid home value → real exchange succeeds ────
  test('valid exchange creates exchange record, consumption, destination lot '
      'and conserves balance', () async {
    // Seed 1000 SAR (home cash) with a cost basis so it can be exchanged.
    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: 1000,
      currencyCode: 'SAR',
      homeCurrencyAmount: 1000,
      homeCurrencyCode: 'SAR',
    );

    expect(await balanceFor('SAR'), closeTo(1000, 0.000001));
    expect(await balanceFor('THB'), closeTo(0, 0.000001));

    final result = await exchangeUseCase.execute(
      tripId: trip.id,
      fromCurrencyCode: 'SAR',
      fromAmount: 500,
      toCurrencyCode: 'THB',
      toAmount: 9600,
    );

    // 1. Exchange record exists.
    expect(result.exchange.fromCurrencyCode, 'SAR');
    expect(result.exchange.toCurrencyCode, 'THB');
    expect(result.exchange.fromAmount, closeTo(500, 0.000001));
    expect(result.exchange.toAmount, closeTo(9600, 0.000001));

    // 2. Source consumption exists (source lot chain).
    expect(result.consumptions, isNotEmpty);
    expect(
      result.consumptions.fold<double>(0, (s, c) => s + c.consumedAmount),
      closeTo(500, 0.000001),
    );

    // 3. Destination lot exists with the transferred cost basis.
    expect(result.destinationLot.sourceType, 'exchange_in');
    expect(result.destinationLot.currencyCode, 'THB');
    expect(result.destinationLot.originalAmount, closeTo(9600, 0.000001));
    expect(result.destinationLot.homeCurrencyAmount, closeTo(500, 0.000001));

    // 4. Balance conservation: source down by fromAmount, destination up by
    //    toAmount — no cash created from nothing.
    expect(await balanceFor('SAR'), closeTo(500, 0.000001));
    expect(await balanceFor('THB'), closeTo(9600, 0.000001));
  });

  // ── Test 3 — Direct currencyExchangeIn via addCashTransaction must fail ─────
  test('addCashTransaction rejects currencyExchangeIn and writes nothing',
      () async {
    expect(
      () => walletRepo.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.currencyExchangeIn,
        amount: 720,
        currencyCode: 'CNY',
      ),
      throwsA(isA<ArgumentError>()),
    );

    // No lot, no transaction, no balance change.
    expect(await balanceFor('CNY'), closeTo(0, 0.000001));
    final transactions = await walletRepo.getRecentTransactionsByTrip(
      trip.id,
      includeReversed: true,
    );
    expect(transactions, isEmpty);
  });
}
