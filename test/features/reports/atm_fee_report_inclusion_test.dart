import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

/// End-to-end: an ATM withdrawal fee (in the home currency) must show up in the
/// report's headline home-currency spending total, while the cash lot cost
/// basis stays `charged - fee` (520, not 530).
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

  const calc = TripReportCalculator();

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'atm_fee_report');
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
        id: 'trip-atm-report',
        name: 'ATM Report Trip',
        destination: 'China',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  test('ATM fee is included in home-currency gross spending total', () async {
    // Received 1000 CNY, charged 530 SAR, fee 10 SAR, home = SAR.
    final result = await useCase.execute(
      tripId: trip.id,
      receivedAmount: 1000,
      receivedCurrency: 'CNY',
      chargedAmount: 530,
      chargedCurrency: 'SAR',
      feeAmount: 10,
      feeCurrency: 'SAR',
      homeCurrencyCode: 'SAR',
    );

    // Cash lot cost basis stays 520 SAR (charged - fee), never 530.
    expect(result.cashLot.homeCurrencyAmount, closeTo(520.0, 1e-6));

    final expenses = await expenseRepo.getExpensesByTrip(trip.id);
    final summary = calc.calculate(
      tripId: trip.id,
      tripName: trip.name,
      expenses: expenses,
      tripHomeCurrency: 'SAR',
    );

    // The 10 SAR fee is the only expense and counts toward the home total.
    expect(summary.grossSpendingHomeAmount, closeTo(10.0, 1e-6));
    expect(summary.grossSpendingHomeCurrency, 'SAR');

    // It is not double-counted and not left dangling as a "pending" card
    // expense (its home value is known).
    expect(summary.pendingCardExpenseCount, 0);
  });
}
