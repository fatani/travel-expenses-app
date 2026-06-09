import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';

import '../../../support/isolated_app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late Trip trip;
  late ExpenseRefundRepository refundRepository;

  setUp(() async {
    appDatabase = createIsolatedAppDatabase(prefix: 'refund_repo');
    final tripRepository = TripRepository(appDatabase);
    refundRepository = ExpenseRefundRepository(appDatabase);
    trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-refund-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Refund Test Trip',
        destination: 'Tokyo',
        baseCurrency: 'JPY',
        destinationCurrency: 'JPY',
        homeCurrencySnapshot: 'SAR',
      ),
    );
  });

  tearDown(() async {
    await appDatabase.close();
  });

  Future<double> cashBalance(String currency) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      AppDatabase.tripCashBalancesTable,
      where: 'trip_id = ? AND currency_code = ?',
      whereArgs: [trip.id, currency],
      limit: 1,
    );
    if (rows.isEmpty) return 0.0;
    return (rows.first['balance_amount'] as num).toDouble();
  }

  Future<int> refundRowCount({bool includeReversed = true}) async {
    final db = await appDatabase.database;
    final where = includeReversed ? 'trip_id = ?' : 'trip_id = ? AND is_reversed = 0';
    final rows = await db.query(
      AppDatabase.expenseRefundsTable,
      where: where,
      whereArgs: [trip.id],
    );
    return rows.length;
  }

  Future<int> cashTxCountByType(String type) async {
    final db = await appDatabase.database;
    final rows = await db.query(
      AppDatabase.cashTransactionsTable,
      where: 'trip_id = ? AND type = ? AND is_reversed = 0',
      whereArgs: [trip.id, type],
    );
    return rows.length;
  }

  // ---------------------------------------------------------------------------
  // Table existence
  // ---------------------------------------------------------------------------

  test('expense_refunds table exists after database open', () async {
    final db = await appDatabase.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='expense_refunds'",
    );
    expect(tables, isNotEmpty);
  });

  // ---------------------------------------------------------------------------
  // Card refund — creates only refund row
  // ---------------------------------------------------------------------------

  test('card refund creates refund row only — no cash transaction', () async {
    await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 50.0,
      currencyCode: 'JPY',
    );

    expect(await refundRowCount(), 1);
    expect(await cashTxCountByType('cash_refund'), 0);
    expect(await cashBalance('JPY'), 0.0);
  });

  // ---------------------------------------------------------------------------
  // Cash refund — atomic: refund row + cash transaction
  // ---------------------------------------------------------------------------

  test('cash refund creates refund row and cash transaction atomically', () async {
    await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 200.0,
      currencyCode: 'JPY',
    );

    expect(await refundRowCount(), 1);
    expect(await cashTxCountByType('cash_refund'), 1);
  });

  test('cash refund increases wallet balance', () async {
    expect(await cashBalance('JPY'), 0.0);

    await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 300.0,
      currencyCode: 'JPY',
    );

    expect(await cashBalance('JPY'), 300.0);
  });

  // ---------------------------------------------------------------------------
  // Reversals
  // ---------------------------------------------------------------------------

  test('reversing cash refund restores wallet balance to zero', () async {
    final refund = await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 150.0,
      currencyCode: 'JPY',
    );
    expect(await cashBalance('JPY'), 150.0);

    await refundRepository.reverseCashRefund(refund);

    expect(await cashBalance('JPY'), 0.0);
  });

  test('reversing cash refund marks refund row as reversed', () async {
    final refund = await refundRepository.createCashRefund(
      tripId: trip.id,
      amount: 150.0,
      currencyCode: 'JPY',
    );

    await refundRepository.reverseCashRefund(refund);

    expect(await refundRowCount(includeReversed: true), 1);
    expect(await refundRowCount(includeReversed: false), 0);
  });

  test('reversing card refund only marks refund row reversed — no cash impact', () async {
    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 100.0,
      currencyCode: 'JPY',
    );

    await refundRepository.reverseCardRefund(refund);

    expect(await refundRowCount(includeReversed: false), 0);
    expect(await refundRowCount(includeReversed: true), 1);
    expect(await cashBalance('JPY'), 0.0);
  });

  test('reverseCardRefund throws StateError when refund is already reversed', () async {
    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 100.0,
      currencyCode: 'JPY',
    );

    await refundRepository.reverseCardRefund(refund);
    final alreadyReversed = refund.copyWith(isReversed: false);

    await expectLater(
      refundRepository.reverseCardRefund(alreadyReversed),
      throwsA(isA<StateError>()),
    );
  });

  test('reverseCardRefund throws StateError when called on already-reversed instance', () async {
    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      amount: 100.0,
      currencyCode: 'JPY',
    );

    await expectLater(
      refundRepository.reverseCardRefund(refund.copyWith(isReversed: true)),
      throwsA(isA<StateError>()),
    );
  });

  // ---------------------------------------------------------------------------
  // Multiple partial refunds
  // ---------------------------------------------------------------------------

  test('multiple partial card refunds for same expense are all stored', () async {
    await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: 'exp1',
      amount: 30.0,
      currencyCode: 'JPY',
    );
    await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: 'exp1',
      amount: 20.0,
      currencyCode: 'JPY',
    );

    expect(await refundRowCount(), 2);
  });

  // ---------------------------------------------------------------------------
  // Over-refund guard
  // ---------------------------------------------------------------------------

  test('over-refund is rejected when homeAmount exceeds expense convertedHomeAmount', () async {
    final expense = Expense.create(
      id: 'exp-guard-${DateTime.now().microsecondsSinceEpoch}',
      tripId: trip.id,
      title: 'Hotel',
      amount: 10000.0,
      currencyCode: 'JPY',
      convertedHomeAmount: 250.0,
      homeCurrency: 'SAR',
      conversionRate: 0.025,
      paymentMethod: 'Card',
    );

    expect(
      () => refundRepository.createCardRefund(
        tripId: trip.id,
        expenseId: expense.id,
        amount: 10000.0,
        currencyCode: 'JPY',
        homeAmount: 300.0,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      ),
      throwsA(isA<RefundOverLimitException>()),
    );
  });

  test('reversed refunds are excluded from over-refund guard sum', () async {
    final expense = Expense.create(
      id: 'exp-rev-${DateTime.now().microsecondsSinceEpoch}',
      tripId: trip.id,
      title: 'Flight',
      amount: 50000.0,
      currencyCode: 'JPY',
      convertedHomeAmount: 500.0,
      homeCurrency: 'SAR',
      conversionRate: 0.01,
      paymentMethod: 'Card',
    );

    final firstRefund = await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: expense.id,
      amount: 20000.0,
      currencyCode: 'JPY',
      homeAmount: 200.0,
      homeCurrency: 'SAR',
      linkedExpense: expense,
    );

    await refundRepository.reverseCardRefund(firstRefund);

    // After reversal the 200 SAR is no longer counted — a new 300 SAR refund
    // must be accepted even though 200+300 > 500.
    await expectLater(
      refundRepository.createCardRefund(
        tripId: trip.id,
        expenseId: expense.id,
        amount: 30000.0,
        currencyCode: 'JPY',
        homeAmount: 300.0,
        homeCurrency: 'SAR',
        linkedExpense: expense,
      ),
      completes,
    );
  });

  // ---------------------------------------------------------------------------
  // homeAmount auto-derivation
  // ---------------------------------------------------------------------------

  test('homeAmount is derived from expense conversionRate when not supplied', () async {
    final expense = Expense.create(
      id: 'exp-derive-${DateTime.now().microsecondsSinceEpoch}',
      tripId: trip.id,
      title: 'Dinner',
      amount: 4000.0,
      currencyCode: 'JPY',
      convertedHomeAmount: 100.0,
      homeCurrency: 'SAR',
      conversionRate: 0.025,
      paymentMethod: 'Card',
    );

    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: expense.id,
      amount: 2000.0,
      currencyCode: 'JPY',
      linkedExpense: expense,
    );

    // 2000 * 0.025 = 50.0
    expect(refund.homeAmount, closeTo(50.0, 0.0001));
    expect(refund.homeCurrency, 'SAR');
  });

  test('homeAmount falls back to proportional when conversionRate is null', () async {
    final expense = Expense.create(
      id: 'exp-prop-${DateTime.now().microsecondsSinceEpoch}',
      tripId: trip.id,
      title: 'Taxi',
      amount: 2000.0,
      currencyCode: 'JPY',
      convertedHomeAmount: 80.0,
      homeCurrency: 'SAR',
      paymentMethod: 'Card',
    );

    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: expense.id,
      amount: 1000.0,
      currencyCode: 'JPY',
      linkedExpense: expense,
    );

    // (1000 / 2000) * 80 = 40.0
    expect(refund.homeAmount, closeTo(40.0, 0.0001));
    expect(refund.homeCurrency, 'SAR');
  });

  test('caller-supplied homeAmount takes precedence over derivation', () async {
    // expense: 1000 JPY, convertedHomeAmount=50 SAR, rate=0.025
    // derivation would give 500 * 0.025 = 12.5 SAR
    // caller supplies 18.0 SAR which is < 50 SAR limit
    final expense = Expense.create(
      id: 'exp-override-${DateTime.now().microsecondsSinceEpoch}',
      tripId: trip.id,
      title: 'Museum',
      amount: 1000.0,
      currencyCode: 'JPY',
      convertedHomeAmount: 50.0,
      homeCurrency: 'SAR',
      conversionRate: 0.025,
      paymentMethod: 'Card',
    );

    final refund = await refundRepository.createCardRefund(
      tripId: trip.id,
      expenseId: expense.id,
      amount: 500.0,
      currencyCode: 'JPY',
      homeAmount: 18.0,
      homeCurrency: 'SAR',
      linkedExpense: expense,
    );

    // Must store 18.0, not the derived 12.5
    expect(refund.homeAmount, 18.0);
  });
}
