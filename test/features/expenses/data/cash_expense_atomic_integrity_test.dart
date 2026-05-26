import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Trip trip;
  late ExpenseRepository expenseRepository;
  late CashWalletRepository cashWalletRepository;

  setUp(() async {
    appDatabase = AppDatabase();
    final tripRepository = TripRepository(appDatabase);
    expenseRepository = ExpenseRepository(appDatabase);
    cashWalletRepository = CashWalletRepository(appDatabase);
    trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-atomic-${DateTime.now().microsecondsSinceEpoch}',
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

  Expense cashExpenseDraft({
    String title = 'Cash lunch',
    double amount = 120,
  }) {
    return Expense.create(
      tripId: trip.id,
      title: title,
      amount: amount,
      currencyCode: 'THB',
      transactionAmount: amount,
      transactionCurrency: 'THB',
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
      spentAt: DateTime(2026, 5, 16),
    );
  }

  ProviderContainer buildContainer({
    CashWalletRepository? cashWalletOverride,
  }) {
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
        cashWalletRepositoryProvider.overrideWithValue(
          cashWalletOverride ?? cashWalletRepository,
        ),
      ],
    );
  }

  Future<double> walletBalance() async {
    final balances = await cashWalletRepository.getBalancesByTrip(trip.id);
    return balances
            .where((b) => b.currencyCode == 'THB')
            .map((b) => b.balanceAmount)
            .firstOrNull ??
        0;
  }

  group('Stage 1.7.1 — cash expense atomic integrity', () {
    test('cash expense persists expense and wallet deduction together', () async {
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 500,
        currencyCode: 'THB',
      );

      final db = await appDatabase.database;
      await db.transaction((txn) async {
        final created = await expenseRepository.createExpense(
          cashExpenseDraft(),
          txn: txn,
        );
        await cashWalletRepository.recordCashExpenseDeduction(
          tripId: trip.id,
          expenseId: created.id,
          amount: created.transactionAmount,
          currencyCode: created.transactionCurrency,
          txn: txn,
        );
      });

      final expenses = await expenseRepository.getExpensesByTrip(trip.id);
      expect(expenses, hasLength(1));

      final transactions = await cashWalletRepository.getRecentTransactionsByTrip(
        trip.id,
      );
      expect(
        transactions.where((t) => t.type == CashTransactionType.cashExpenseDeduction),
        hasLength(1),
      );
      expect(await walletBalance(), closeTo(380, 0.000001));
    });

    test('wallet deduction failure rolls back expense insert', () async {
      final failingWallet = _FailingDeductionCashWalletRepository(appDatabase);

      await expectLater(
        () async {
          final db = await appDatabase.database;
          await db.transaction((txn) async {
            final created = await expenseRepository.createExpense(
              cashExpenseDraft(),
              txn: txn,
            );
            await failingWallet.recordCashExpenseDeduction(
              tripId: trip.id,
              expenseId: created.id,
              amount: created.transactionAmount,
              currencyCode: created.transactionCurrency,
              txn: txn,
            );
          });
        }(),
        throwsA(isA<StateError>()),
      );

      expect(await expenseRepository.getExpensesByTrip(trip.id), isEmpty);
      final transactions = await cashWalletRepository.getRecentTransactionsByTrip(
        trip.id,
      );
      expect(transactions, isEmpty);
    });

    test('expense insert failure does not write wallet transaction', () async {
      final expenseId = 'duplicate-expense-${DateTime.now().microsecondsSinceEpoch}';
      final draft = cashExpenseDraft().copyWith(id: expenseId);
      final duplicate = draft.copyWith(title: 'Duplicate title');

      await expectLater(
        () async {
          final db = await appDatabase.database;
          await db.transaction((txn) async {
            await expenseRepository.createExpense(draft, txn: txn);
            await expenseRepository.createExpense(duplicate, txn: txn);
            await cashWalletRepository.recordCashExpenseDeduction(
              tripId: trip.id,
              expenseId: duplicate.id,
              amount: duplicate.transactionAmount,
              currencyCode: duplicate.transactionCurrency,
              txn: txn,
            );
          });
        }(),
        throwsA(anything),
      );

      expect(await expenseRepository.getExpensesByTrip(trip.id), isEmpty);
      final transactions = await cashWalletRepository.getRecentTransactionsByTrip(
        trip.id,
      );
      expect(transactions, isEmpty);
    });

    test('controller does not return success when wallet deduction fails', () async {
      final container = buildContainer(
        cashWalletOverride: _FailingDeductionCashWalletRepository(appDatabase),
      );
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      await expectLater(
        controller.createExpense(
          title: 'Cash snack',
          amount: 40,
          currencyCode: 'THB',
          category: 'Food',
          spentAt: DateTime(2026, 5, 16),
          paymentMethod: 'Cash',
          paymentChannel: 'Cash',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await expenseRepository.getExpensesByTrip(trip.id), isEmpty);
    });

    test('non-cash expense creation still works without wallet deduction', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      final outcome = await controller.createExpense(
        title: 'Card dinner',
        amount: 90,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 16),
        paymentMethod: 'Credit Card',
        paymentChannel: 'POS Purchase',
      );

      expect(outcome.createdExpenseId, isNotNull);
      expect(outcome.cashBalanceInsufficient, isFalse);

      final expenses = await expenseRepository.getExpensesByTrip(trip.id);
      expect(expenses, hasLength(1));

      final transactions = await cashWalletRepository.getRecentTransactionsByTrip(
        trip.id,
      );
      expect(
        transactions.where((t) => t.type == CashTransactionType.cashExpenseDeduction),
        isEmpty,
      );
    });

    test('insufficient balance warning still reports correctly', () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      final outcome = await controller.createExpense(
        title: 'Cash overdraft',
        amount: 250,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 16),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
      );

      expect(outcome.cashBalanceInsufficient, isTrue);
      expect(outcome.noCashBalanceRecorded, isTrue);
      expect(await walletBalance(), closeTo(-250, 0.000001));
      expect((await expenseRepository.getExpensesByTrip(trip.id)), hasLength(1));
    });

    test('duplicate submit does not create duplicate cash expense rows', () async {
      final fixedId = 'fixed-cash-expense-${DateTime.now().microsecondsSinceEpoch}';
      final draft = cashExpenseDraft().copyWith(id: fixedId);

      await expenseRepository.createExpense(draft);

      var duplicateRejected = false;
      try {
        await expenseRepository.createExpense(draft);
      } on Object {
        duplicateRejected = true;
      }

      expect(duplicateRejected, isTrue);

      final db = await appDatabase.database;
      final rows = await db.query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [fixedId],
      );
      expect(rows.length, 1);
    });

    test('controller cash save commits expense and deduction atomically', () async {
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 300,
        currencyCode: 'THB',
      );

      final container = buildContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        expenseControllerProvider(trip.id).notifier,
      );

      final outcome = await controller.createExpense(
        title: 'Street food',
        amount: 75,
        currencyCode: 'THB',
        category: 'Food',
        spentAt: DateTime(2026, 5, 16),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
      );

      expect(outcome.createdExpenseId, isNotNull);
      expect(outcome.cashBalanceInsufficient, isFalse);
      expect(await walletBalance(), closeTo(225, 0.000001));
      expect((await expenseRepository.getExpensesByTrip(trip.id)), hasLength(1));
    });
  });
}

class _FailingDeductionCashWalletRepository extends CashWalletRepository {
  _FailingDeductionCashWalletRepository(super.appDatabase);

  @override
  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
    DatabaseExecutor? txn,
  }) {
    throw StateError('wallet deduction failed');
  }
}
