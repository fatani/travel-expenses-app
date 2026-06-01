import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/features/backup/data/backup_data_collector.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_balance_recompute.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  Map<String, dynamic> txn({
    required String id,
    required String tripId,
    required CashTransactionType type,
    required double amount,
    String currencyCode = 'USD',
    bool isReversed = false,
    String createdAt = '2026-06-01T10:00:00.000Z',
    String? expenseId,
  }) {
    return {
      'id': id,
      'trip_id': tripId,
      'expense_id': expenseId,
      'type': type.value,
      'amount': amount,
      'currency_code': currencyCode,
      'is_reversed': isReversed ? 1 : 0,
      'created_at': createdAt,
    };
  }

  test('recomputes signed deltas per currency and trip', () {
    final balances = CashBalanceRecompute.recomputeBalancesFromTransactions([
      txn(
        id: 't1',
        tripId: 'trip-a',
        type: CashTransactionType.initialCash,
        amount: 100,
      ),
      txn(
        id: 't2',
        tripId: 'trip-a',
        type: CashTransactionType.cashExpenseDeduction,
        amount: 30,
        createdAt: '2026-06-01T11:00:00.000Z',
      ),
      txn(
        id: 't3',
        tripId: 'trip-b',
        type: CashTransactionType.atmWithdrawal,
        amount: 50,
        currencyCode: 'EUR',
      ),
    ]);

    expect(balances['trip-a']!['USD'], closeTo(70, 0.001));
    expect(balances['trip-b']!['EUR'], closeTo(50, 0.001));
  });

  test('ignores reversed transactions', () {
    final balances = CashBalanceRecompute.recomputeBalancesFromTransactions([
      txn(
        id: 't1',
        tripId: 'trip-a',
        type: CashTransactionType.initialCash,
        amount: 100,
        isReversed: true,
      ),
      txn(
        id: 't2',
        tripId: 'trip-a',
        type: CashTransactionType.manualAdjustment,
        amount: 40,
      ),
    ]);

    expect(balances['trip-a']!['USD'], closeTo(40, 0.001));
  });

  test('matches repository balances for live database snapshot', () async {
    final appDatabase = createIsolatedAppDatabase(prefix: 'cash_recompute');
    addTearDown(() async => appDatabase.close());

    final trip = await TripRepository(appDatabase).createTrip(
      Trip.create(
        name: 'Bangkok',
        destination: 'Bangkok',
        baseCurrency: 'THB',
        destinationCurrency: 'THB',
      ),
    );
    final wallet = CashWalletRepository(appDatabase);

    await wallet.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.initialCash,
      amount: 1000,
      currencyCode: 'THB',
    );
    await wallet.addCashTransaction(
      tripId: trip.id,
      type: CashTransactionType.manualAdjustment,
      amount: 200,
      currencyCode: 'THB',
    );
    final adjustment = (await wallet.getRecentTransactionsByTrip(
      trip.id,
      includeReversed: true,
      limit: 10,
    )).firstWhere((txn) => txn.type == CashTransactionType.manualAdjustment);
    await wallet.reverseManualCashTransaction(transaction: adjustment);

    final storedBalances = await wallet.getBalancesByTrip(trip.id);
    final collected = await BackupDataCollector(appDatabase).collect();
    final recomputed = CashBalanceRecompute.recomputeBalancesFromTransactions(
      collected.cashTransactions,
    );

    for (final balance in storedBalances) {
      expect(
        recomputed[balance.tripId]![balance.currencyCode],
        closeTo(balance.balanceAmount, 0.000001),
      );
    }

    await appDatabase.close();
  });

  test('materializes TripCashBalance rows', () {
    final rows = CashBalanceRecompute.recomputeTripCashBalances([
      txn(
        id: 't1',
        tripId: 'trip-a',
        type: CashTransactionType.currencyExchangeIn,
        amount: 25,
        currencyCode: 'JPY',
      ),
    ], updatedAt: DateTime.utc(2026, 6, 1));

    expect(rows, hasLength(1));
    expect(rows.single.tripId, 'trip-a');
    expect(rows.single.currencyCode, 'JPY');
    expect(rows.single.balanceAmount, closeTo(25, 0.001));
  });
}
