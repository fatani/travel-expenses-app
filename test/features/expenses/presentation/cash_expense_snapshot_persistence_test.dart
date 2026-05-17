import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'cash snapshots are fully saved at creation and remain immutable after later inflows',
    () async {

      final appDatabase = AppDatabase();
      addTearDown(() async {
        await appDatabase.close();
      });

      final tripRepository = TripRepository(appDatabase);
      final expenseRepository = ExpenseRepository(appDatabase);
      final cashWalletRepository = CashWalletRepository(appDatabase);

      final trip = await tripRepository.createTrip(
        Trip.create(
          id: 'trip-persist-${DateTime.now().microsecondsSinceEpoch}',
          name: 'Bangkok',
          destination: 'Bangkok',
          baseCurrency: 'THB',
          destinationCurrency: 'THB',
          homeCurrencySnapshot: 'SAR',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(appDatabase),
          expenseRepositoryProvider.overrideWithValue(expenseRepository),
          cashWalletRepositoryProvider.overrideWithValue(cashWalletRepository),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      // Initial cash: 50,000 THB ≈ 5,250 SAR => rate A = 0.105
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 50000,
        currencyCode: 'THB',
        homeCurrencyAmount: 5250,
        homeCurrencyCode: 'SAR',
      );

      await controller.createExpense(
        title: 'A',
        amount: 500,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 16),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      var expenses = await expenseRepository.getExpensesByTrip(trip.id);
      final a = expenses.singleWhere((expense) => expense.title == 'A');

      expect(a.originalAmount, closeTo(500, 0.000001));
      expect(a.originalCurrency, 'THB');
      expect(a.conversionRate, closeTo(0.105, 0.000001));
      expect(a.convertedHomeAmount, closeTo(52.5, 0.000001));
      expect(a.homeCurrency, 'SAR');
      expect(a.paymentMethod, 'Cash');
      expect(a.paymentChannel, 'Cash');

      // Add ATM cash: 30,000 THB ≈ 3,300 SAR => pooled rate = 8550/80000
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.atmWithdrawal,
        amount: 30000,
        currencyCode: 'THB',
        homeCurrencyAmount: 3300,
        homeCurrencyCode: 'SAR',
      );

      final aAfterAtm = await expenseRepository.getExpenseById(a.id);
      expect(aAfterAtm, isNotNull);
      expect(aAfterAtm!.conversionRate, closeTo(0.105, 0.000001));
      expect(aAfterAtm.convertedHomeAmount, closeTo(52.5, 0.000001));
      expect(aAfterAtm.originalAmount, closeTo(500, 0.000001));
      expect(aAfterAtm.originalCurrency, 'THB');
      expect(aAfterAtm.homeCurrency, 'SAR');

      await controller.createExpense(
        title: 'B',
        amount: 500,
        currencyCode: 'THB',
        category: 'Transport',
        spentAt: DateTime(2026, 5, 16),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        tripHomeCurrency: 'SAR',
      );

      expenses = await expenseRepository.getExpensesByTrip(trip.id);
      final b = expenses.singleWhere((expense) => expense.title == 'B');
      final pooledRateAfterAtm = 8550.0 / 80000.0;
      expect(b.conversionRate, closeTo(pooledRateAfterAtm, 0.000001));
      expect(b.convertedHomeAmount, closeTo(500 * pooledRateAfterAtm, 0.000001));
      expect(b.originalAmount, closeTo(500, 0.000001));
      expect(b.originalCurrency, 'THB');
      expect(b.homeCurrency, 'SAR');

      // Third-rate inflow: 10,000 THB ≈ 1,200 SAR
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.currencyExchangeIn,
        amount: 10000,
        currencyCode: 'THB',
        homeCurrencyAmount: 1200,
        homeCurrencyCode: 'SAR',
      );

      final aAfterThirdInflow = await expenseRepository.getExpenseById(a.id);
      final bAfterThirdInflow = await expenseRepository.getExpenseById(b.id);
      expect(aAfterThirdInflow, isNotNull);
      expect(bAfterThirdInflow, isNotNull);

      expect(aAfterThirdInflow!.conversionRate, closeTo(0.105, 0.000001));
      expect(aAfterThirdInflow.convertedHomeAmount, closeTo(52.5, 0.000001));
      expect(bAfterThirdInflow!.conversionRate, closeTo(pooledRateAfterAtm, 0.000001));
      expect(
        bAfterThirdInflow.convertedHomeAmount,
        closeTo(500 * pooledRateAfterAtm, 0.000001),
      );
    },
  );
}
