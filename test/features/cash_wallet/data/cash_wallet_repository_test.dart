import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Trip trip;
  late CashWalletRepository repository;

  setUp(() async {
    appDatabase = AppDatabase();
    final tripRepository = TripRepository(appDatabase);
    repository = CashWalletRepository(appDatabase);
    trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-cash-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Test Trip',
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
    final balances = await repository.getBalancesByTrip(trip.id);
    return balances
            .where((b) => b.currencyCode == currency)
            .map((b) => b.balanceAmount)
            .firstOrNull ??
        0;
  }

  Expense cashExpense({
    required String id,
    required double amount,
    String currency = 'THB',
  }) {
    return Expense.create(
      id: id,
      tripId: trip.id,
      title: 'Cash expense $id',
      amount: amount,
      currencyCode: currency,
      transactionAmount: amount,
      transactionCurrency: currency,
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
    );
  }

  Expense cardExpense({
    required String id,
    required double amount,
    String currency = 'THB',
  }) {
    return Expense.create(
      id: id,
      tripId: trip.id,
      title: 'Card expense $id',
      amount: amount,
      currencyCode: currency,
      transactionAmount: amount,
      transactionCurrency: currency,
      paymentMethod: 'Credit Card',
      paymentChannel: 'POS Purchase',
    );
  }

  group('addCashTransaction', () {
    test('updates balances correctly for inflows and outflows', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'THB',
      );

      expect(await balanceFor('THB'), closeTo(1000, 0.000001));

      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.atmWithdrawal,
        amount: 500,
        currencyCode: 'THB',
      );

      expect(await balanceFor('THB'), closeTo(1500, 0.000001));

      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.currencyExchangeOut,
        amount: 200,
        currencyCode: 'THB',
      );

      expect(await balanceFor('THB'), closeTo(1300, 0.000001));
    });

    test('allows zero initial cash balance', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 0,
        currencyCode: 'THB',
      );

      expect(await balanceFor('THB'), closeTo(0, 0.000001));
    });
  });

  group('reverseManualCashTransaction', () {
    test('restores balance correctly', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 800,
        currencyCode: 'THB',
      );

      final transactions = await repository.getRecentTransactionsByTrip(trip.id);
      final initialCash = transactions.singleWhere(
        (t) => t.type == CashTransactionType.initialCash,
      );

      await repository.reverseManualCashTransaction(transaction: initialCash);

      expect(await balanceFor('THB'), closeTo(0, 0.000001));
    });
  });

  group('syncExpenseCashImpact', () {
    test('cash to cash updates deduction when amount changes', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 5000,
        currencyCode: 'THB',
      );

      final original = cashExpense(id: 'exp-cash-cash', amount: 300);
      await repository.syncExpenseCashImpact(
        previousExpense: null,
        nextExpense: original,
      );
      expect(await balanceFor('THB'), closeTo(4700, 0.000001));

      final updated = original.copyWith(transactionAmount: 450, amount: 450);
      await repository.syncExpenseCashImpact(
        previousExpense: original,
        nextExpense: updated,
      );
      expect(await balanceFor('THB'), closeTo(4550, 0.000001));
    });

    test('cash to non-cash reverses deduction', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 2000,
        currencyCode: 'THB',
      );

      final cash = cashExpense(id: 'exp-cash-card', amount: 250);
      await repository.syncExpenseCashImpact(
        previousExpense: null,
        nextExpense: cash,
      );
      expect(await balanceFor('THB'), closeTo(1750, 0.000001));

      final card = cash.copyWith(
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS Purchase',
      );
      await repository.syncExpenseCashImpact(
        previousExpense: cash,
        nextExpense: card,
      );
      expect(await balanceFor('THB'), closeTo(2000, 0.000001));
    });

    test('non-cash to cash records deduction', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1500,
        currencyCode: 'THB',
      );

      final card = cardExpense(id: 'exp-card-cash', amount: 120);
      await repository.syncExpenseCashImpact(
        previousExpense: null,
        nextExpense: card,
      );
      expect(await balanceFor('THB'), closeTo(1500, 0.000001));

      final cash = card.copyWith(
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
      );
      await repository.syncExpenseCashImpact(
        previousExpense: card,
        nextExpense: cash,
      );
      expect(await balanceFor('THB'), closeTo(1380, 0.000001));
    });

    test('non-cash to non-cash does not change balance', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 900,
        currencyCode: 'THB',
      );

      final cardA = cardExpense(id: 'exp-card-card-a', amount: 50);
      final cardB = cardA.copyWith(transactionAmount: 75, amount: 75);

      await repository.syncExpenseCashImpact(
        previousExpense: null,
        nextExpense: cardA,
      );
      await repository.syncExpenseCashImpact(
        previousExpense: cardA,
        nextExpense: cardB,
      );

      expect(await balanceFor('THB'), closeTo(900, 0.000001));
    });
  });

  group('restoreCashForDeletedExpense', () {
    test('restores deducted balance correctly', () async {
      await repository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 1000,
        currencyCode: 'THB',
      );

      final expense = cashExpense(id: 'exp-delete', amount: 175);
      await repository.recordCashExpenseDeduction(
        tripId: trip.id,
        expenseId: expense.id,
        amount: expense.transactionAmount,
        currencyCode: expense.transactionCurrency,
      );
      expect(await balanceFor('THB'), closeTo(825, 0.000001));

      await repository.restoreCashForDeletedExpense(expense);

      expect(await balanceFor('THB'), closeTo(1000, 0.000001));
    });
  });

  group('negative balance scenario', () {
    test('spend without balance, then reverse restores correctly', () async {
      final expense = cashExpense(id: 'exp-negative', amount: 400);
      await repository.recordCashExpenseDeduction(
        tripId: trip.id,
        expenseId: expense.id,
        amount: expense.transactionAmount,
        currencyCode: expense.transactionCurrency,
      );

      expect(await balanceFor('THB'), closeTo(-400, 0.000001));

      await repository.restoreCashForDeletedExpense(expense);

      expect(await balanceFor('THB'), closeTo(0, 0.000001));
    });
  });

  group('CashTransactionTypeDelta', () {
    test('signedDelta matches repository balance math', () {
      expect(
        CashTransactionType.initialCash.signedDelta(100),
        closeTo(100, 0.000001),
      );
      expect(
        CashTransactionType.cashExpenseDeduction.signedDelta(100),
        closeTo(-100, 0.000001),
      );
    });
  });
}
