import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/record_atm_withdrawal_use_case.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../support/isolated_app_database.dart';

/// ATM Fee Linkage Foundation: a durable `source_ref` on expenses links an ATM
/// fee back to its ATM cash transaction, so a future ATM Safe Undo/Correct can
/// find and reverse the fee reliably (no timestamp/amount guessing).
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

  setUp(() async {
    db = createIsolatedAppDatabase(prefix: 'atm_fee_linkage');
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
        id: 'trip-atm-link',
        name: 'Beijing',
        destination: 'Beijing',
        baseCurrency: 'CNY',
        destinationCurrency: 'CNY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async => db.close());

  // ─── 1. Schema ────────────────────────────────────────────────────────────

  group('1 — schema', () {
    test('DB version is 23', () {
      expect(AppDatabase.databaseVersion, 23);
    });

    test('expenses has source_ref_type and source_ref_id columns', () async {
      final database = await db.database;
      final cols = (await database.rawQuery(
        'PRAGMA table_info(${AppDatabase.expensesTable})',
      ))
          .map((r) => r['name'] as String)
          .toSet();
      expect(cols, containsAll(['source_ref_type', 'source_ref_id']));
    });

    test('source-ref index exists', () async {
      final database = await db.database;
      final indexes = (await database.rawQuery(
        'PRAGMA index_list(${AppDatabase.expensesTable})',
      ))
          .map((r) => r['name'] as String)
          .toSet();
      expect(indexes, contains('idx_expenses_source_ref'));
    });
  });

  // ─── 2. Model round-trip ───────────────────────────────────────────────────

  group('2 — model round-trip', () {
    test('toMap/fromMap preserve source ref', () {
      final expense = Expense.create(
        id: 'fee-1',
        tripId: trip.id,
        title: 'ATM Fee',
        amount: 10,
        currencyCode: 'SAR',
        paymentMethod: 'Credit Card',
        sourceRefType: 'atm_withdrawal',
        sourceRefId: 'atm_123',
      );

      final restored = Expense.fromMap(expense.toMap());
      expect(restored.sourceRefType, 'atm_withdrawal');
      expect(restored.sourceRefId, 'atm_123');
    });

    test('legacy expense with no source ref stays null', () {
      final expense = Expense.create(
        id: 'legacy-1',
        tripId: trip.id,
        title: 'Coffee',
        amount: 20,
        currencyCode: 'CNY',
        paymentMethod: 'Cash',
      );
      final restored = Expense.fromMap(expense.toMap());
      expect(restored.sourceRefType, isNull);
      expect(restored.sourceRefId, isNull);
    });

    test('repository insert/read preserves source ref', () async {
      final created = await expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'ATM Fee',
          amount: 10,
          currencyCode: 'SAR',
          paymentMethod: 'Credit Card',
          paymentChannel: 'ATM Withdrawal Fee',
          category: 'Fees',
          sourceRefType: 'atm_withdrawal',
          sourceRefId: 'atm_456',
        ),
      );
      final read = await expenseRepo.getExpenseById(created.id);
      expect(read!.sourceRefType, 'atm_withdrawal');
      expect(read.sourceRefId, 'atm_456');
    });
  });

  // ─── 3. ATM fee is linked on creation ──────────────────────────────────────

  group('3 — ATM fee linkage', () {
    test('fee points to the ATM cash transaction id', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 1000,
        receivedCurrency: 'CNY',
        chargedAmount: 520,
        chargedCurrency: 'SAR',
        feeAmount: 10,
        feeCurrency: 'SAR',
        homeCurrencyCode: 'SAR',
      );

      final fee = result.feeExpense!;
      expect(fee.sourceRefType, 'atm_withdrawal');
      expect(fee.sourceRefId, result.cashTransaction.id);
      expect(fee.transactionAmount, closeTo(10, 1e-6));
      expect(fee.transactionCurrency, 'SAR');
      expect(fee.convertedHomeAmount, closeTo(10, 1e-6));
      // Cost basis stays charged - fee.
      expect(result.cashLot.homeCurrencyAmount, closeTo(510, 1e-6));

      // The link is persisted, not just returned in memory.
      final stored = await expenseRepo.getExpenseById(fee.id);
      expect(stored!.sourceRefType, 'atm_withdrawal');
      expect(stored.sourceRefId, result.cashTransaction.id);
    });
  });

  // ─── 4. No-fee ATM creates no linked fee ────────────────────────────────────

  group('4 — no-fee ATM', () {
    test('no fee expense and no source-ref row created', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 1000,
        receivedCurrency: 'CNY',
        chargedAmount: 510,
        chargedCurrency: 'SAR',
        homeCurrencyCode: 'SAR',
      );

      expect(result.feeExpense, isNull);
      final expenses = await expenseRepo.getExpensesByTrip(trip.id);
      expect(expenses, isEmpty);
      expect(result.cashLot.homeCurrencyAmount, closeTo(510, 1e-6));
    });
  });

  // ─── 5. Repository source-ref query ─────────────────────────────────────────

  group('5 — getActiveExpensesBySourceRef', () {
    test('returns the linked fee and excludes unrelated/reversed', () async {
      final result = await useCase.execute(
        tripId: trip.id,
        receivedAmount: 1000,
        receivedCurrency: 'CNY',
        chargedAmount: 520,
        chargedCurrency: 'SAR',
        feeAmount: 10,
        feeCurrency: 'SAR',
        homeCurrencyCode: 'SAR',
      );
      final atmTxId = result.cashTransaction.id;

      // Unrelated expense (no source ref) must not match.
      await expenseRepo.createExpense(
        Expense.create(
          tripId: trip.id,
          title: 'Lunch',
          amount: 30,
          currencyCode: 'CNY',
          paymentMethod: 'Cash',
        ),
      );

      final linked =
          await expenseRepo.getActiveExpensesBySourceRef('atm_withdrawal', atmTxId);
      expect(linked, hasLength(1));
      expect(linked.single.id, result.feeExpense!.id);

      // A different source ref id returns nothing.
      final none = await expenseRepo.getActiveExpensesBySourceRef(
        'atm_withdrawal',
        'does-not-exist',
      );
      expect(none, isEmpty);

      // Empty args are handled safely.
      expect(await expenseRepo.getActiveExpensesBySourceRef('', atmTxId), isEmpty);
    });
  });
}
