import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

/// Exchange Edit Conversion Hardening — repository (defense-in-depth) level.
///
/// updateManualCashTransaction must never re-type a manual row into an exchange
/// row, even if a future UI re-exposes the option. Ordinary manual edits stay
/// unaffected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late CashWalletRepository walletRepo;
  late Trip trip;

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'exchange_edit_conversion');
    walletRepo = CashWalletRepository(db);
    trip = await TripRepository(db).createTrip(
      Trip.create(
        id: 'trip-conv-${DateTime.now().microsecondsSinceEpoch}',
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

  Future<CashTransaction> seedManualAdjustment() async {
    await walletRepo.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.manualAdjustment,
      amount: 300,
      currencyCode: 'CNY',
    );
    return (await walletRepo.getRecentTransactionsByTrip(trip.id))
        .firstWhere((t) => t.type == CashTransactionType.manualAdjustment);
  }

  // ── Test 2 — cannot convert a manual row into currencyExchangeIn ───────────
  test('updateManualCashTransaction rejects nextType currencyExchangeIn',
      () async {
    final manual = await seedManualAdjustment();

    await expectLater(
      walletRepo.updateManualCashTransaction(
        existingTransaction: manual,
        nextType: CashTransactionType.currencyExchangeIn,
        nextAmount: 2000,
        nextCurrencyCode: 'CNY',
      ),
      throwsA(isA<ArgumentError>()),
    );

    // No write: the manual row is untouched and no exchange-in lot was created.
    expect(await balanceFor('CNY'), closeTo(300, 0.000001));
    final txns = await walletRepo.getRecentTransactionsByTrip(
      trip.id,
      includeReversed: true,
    );
    expect(
      txns.where((t) => t.type == CashTransactionType.currencyExchangeIn),
      isEmpty,
    );
    expect(
      txns.singleWhere((t) => t.type == CashTransactionType.manualAdjustment)
          .isReversed,
      isFalse,
    );
  });

  // ── Test 3 — cannot convert a manual row into currencyExchangeOut ──────────
  test('updateManualCashTransaction rejects nextType currencyExchangeOut',
      () async {
    final manual = await seedManualAdjustment();

    await expectLater(
      walletRepo.updateManualCashTransaction(
        existingTransaction: manual,
        nextType: CashTransactionType.currencyExchangeOut,
        nextAmount: 100,
        nextCurrencyCode: 'CNY',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(await balanceFor('CNY'), closeTo(300, 0.000001));
  });

  // ── Test 4 — ordinary manual re-type still works ───────────────────────────
  test('updateManualCashTransaction still allows manual-to-manual edits',
      () async {
    final manual = await seedManualAdjustment();

    await walletRepo.updateManualCashTransaction(
      existingTransaction: manual,
      nextType: CashTransactionType.initialCash,
      nextAmount: 500,
      nextCurrencyCode: 'CNY',
    );

    expect(await balanceFor('CNY'), closeTo(500, 0.000001));
  });
}
