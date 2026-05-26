import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/integrity/data_integrity.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_calculator.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late TripRepository tripRepository;
  late ExpenseRepository expenseRepository;
  late CashWalletRepository cashWalletRepository;
  late ManualExchangeRateRepository exchangeRateRepository;
  late Trip trip;

  setUp(() async {
    appDatabase = AppDatabase();
    tripRepository = TripRepository(appDatabase);
    expenseRepository = ExpenseRepository(appDatabase);
    cashWalletRepository = CashWalletRepository(appDatabase);
    exchangeRateRepository = ManualExchangeRateRepository(appDatabase);
    trip = await tripRepository.createTrip(
      Trip.create(
        id: 'trip-${DateTime.now().microsecondsSinceEpoch}',
        name: 'Integrity Trip',
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

  Expense sampleExpense({
    String? id,
    String? tripId,
    double amount = 100,
    String currency = 'THB',
  }) {
    return Expense.create(
      id: id ?? 'exp-${DateTime.now().microsecondsSinceEpoch}',
      tripId: tripId ?? trip.id,
      title: 'Sample',
      amount: amount,
      currencyCode: currency,
      transactionAmount: amount,
      transactionCurrency: currency,
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      convertedHomeAmount: 12,
      homeCurrency: 'SAR',
      conversionRate: 0.12,
    );
  }

  group('Stage 1.5 — Trip ↔ expense integrity', () {
    test('deleting trip does not leave orphaned expenses', () async {
      await expenseRepository.createExpense(sampleExpense());
      await tripRepository.deleteTrip(trip.id);

      final db = await appDatabase.database;
      final orphanRows = await db.query(
        AppDatabase.expensesTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(orphanRows, isEmpty);
    });

    test('invalid or missing tripId is rejected on create', () async {
      await expectLater(
        expenseRepository.createExpense(
          sampleExpense(tripId: 'missing-trip'),
        ),
        throwsA(isA<DataIntegrityException>()),
      );

      await expectLater(
        expenseRepository.createExpense(sampleExpense(tripId: '   ')),
        throwsA(isA<DataIntegrityException>()),
      );
    });
  });

  group('Stage 1.5 — Currency integrity', () {
    test('invalid currency code is rejected', () async {
      await expectLater(
        expenseRepository.createExpense(sampleExpense(currency: 'US')),
        throwsA(isA<DataIntegrityException>()),
      );

      expect(
        () => Trip.create(
          name: 'Bad currency',
          destination: 'Nowhere',
          baseCurrency: '123',
        ),
        throwsA(isA<DataIntegrityException>()),
      );
    });
  });

  group('Stage 1.5 — Exchange rate integrity', () {
    test('same source/target exchange rate is rejected', () async {
      expect(
        () => ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'USD',
          rate: 1,
        ),
        throwsA(isA<DataIntegrityException>()),
      );
    });

    test('zero/negative exchange rate is rejected', () async {
      expect(
        () => ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'THB',
          rate: 0,
        ),
        throwsA(isA<DataIntegrityException>()),
      );

      expect(
        () => ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'THB',
          rate: -2,
        ),
        throwsA(isA<DataIntegrityException>()),
      );
    });

    test('deleting trip removes trip-scoped manual exchange rates', () async {
      await exchangeRateRepository.saveRate(
        ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'THB',
          rate: 33,
        ),
      );

      await tripRepository.deleteTrip(trip.id);

      final db = await appDatabase.database;
      final rows = await db.query(
        AppDatabase.manualExchangeRatesTable,
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      expect(rows, isEmpty);
    });

    test('new exchange rates do not rewrite historical expense snapshots', () async {
      final expense = await expenseRepository.createExpense(
        sampleExpense(
          amount: 50,
          currency: 'USD',
        ).copyWith(
          convertedHomeAmount: 187.5,
          homeCurrency: 'SAR',
          conversionRate: 3.75,
        ),
      );

      await exchangeRateRepository.saveRate(
        ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'THB',
          rate: 35,
        ),
      );
      await exchangeRateRepository.saveRate(
        ManualExchangeRate.create(
          tripId: trip.id,
          fromCurrency: 'USD',
          toCurrency: 'THB',
          rate: 40,
        ),
      );

      final reloaded = await expenseRepository.getExpenseById(expense.id);
      expect(reloaded?.conversionRate, 3.75);
      expect(reloaded?.convertedHomeAmount, 187.5);
      expect(reloaded?.homeCurrency, 'SAR');
    });
  });

  group('Stage 1.5 — Cash wallet integrity', () {
    test('cash totals remain consistent after edit/delete style flows', () async {
      await cashWalletRepository.addCashTransaction(
        tripId: trip.id,
        type: CashTransactionType.initialCash,
        amount: 500,
        currencyCode: 'THB',
      );

      final expense = await expenseRepository.createExpense(
        sampleExpense(amount: 120),
      );
      await cashWalletRepository.recordCashExpenseDeduction(
        tripId: trip.id,
        expenseId: expense.id,
        amount: 120,
        currencyCode: 'THB',
      );

      await expenseRepository.deleteExpense(expense.id);
      await cashWalletRepository.restoreCashForDeletedExpense(expense);

      final balances = await cashWalletRepository.getBalancesByTrip(trip.id);
      final thb = balances.firstWhere((b) => b.currencyCode == 'THB');
      expect(thb.balanceAmount, closeTo(500, 0.0001));
    });

    test('invalid cash input is rejected', () async {
      await expectLater(
        cashWalletRepository.addCashTransaction(
          tripId: trip.id,
          type: CashTransactionType.atmWithdrawal,
          amount: 0,
          currencyCode: 'THB',
        ),
        throwsA(isA<DataIntegrityException>()),
      );
    });
  });

  group('Stage 1.5 — Duplicate entity prevention', () {
    test('duplicate submit does not create duplicate entities', () async {
      final duplicateId = 'fixed-expense-id-${DateTime.now().microsecondsSinceEpoch}';
      final expense = sampleExpense(id: duplicateId);
      await expenseRepository.createExpense(expense);

      var duplicateRejected = false;
      try {
        await expenseRepository.createExpense(expense);
      } on Object {
        duplicateRejected = true;
      }
      expect(duplicateRejected, isTrue);

      final rows = await (await appDatabase.database).query(
        AppDatabase.expensesTable,
        where: 'id = ?',
        whereArgs: [duplicateId],
      );
      expect(rows.length, 1);
    });
  });

  group('Stage 1.5 — Defensive parsing', () {
    test('malformed persisted expense row does not crash list parsing', () async {
      final db = await appDatabase.database;
      final badRowId = 'bad-row-${DateTime.now().microsecondsSinceEpoch}';
      await db.insert(AppDatabase.expensesTable, {
        'id': badRowId,
        'trip_id': trip.id,
        'title': '',
        'amount': 10,
        'currency_code': 'THB',
        'transaction_amount': 10,
        'transaction_currency': 'THB',
        'is_international': 0,
        'spent_at': 'not-a-date',
        'payment_method': 'Cash',
        'source': 'manual',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      final expenses = await expenseRepository.getExpensesByTrip(trip.id);
      expect(expenses.every((e) => e.id != badRowId), isTrue);
    });

    test('Expense.tryFromMap returns null for malformed map', () {
      expect(Expense.tryFromMap(const {}), isNull);
    });
  });

  group('Stage 1.5 — Reports / aggregates consistency', () {
    test('reports do not count deleted expenses', () async {
      final expense = await expenseRepository.createExpense(sampleExpense());
      final before = const TripReportCalculator().calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: await expenseRepository.getExpensesByTrip(trip.id),
      );
      expect(before.totalExpenseCount, 1);

      await expenseRepository.deleteExpense(expense.id);
      final after = const TripReportCalculator().calculate(
        tripId: trip.id,
        tripName: trip.name,
        expenses: await expenseRepository.getExpensesByTrip(trip.id),
      );
      expect(after.totalExpenseCount, 0);
    });

    test('deleted trip reports do not crash global calculator', () async {
      await expenseRepository.createExpense(sampleExpense());
      final tripsBefore = await tripRepository.getTrips();
      final expensesBefore = await expenseRepository.getExpensesByTrip(trip.id);

      await tripRepository.deleteTrip(trip.id);

      final tripsAfter = await tripRepository.getTrips();
      expect(
        () => const GlobalReportCalculator().calculate(
          trips: tripsAfter,
          expenses: expensesBefore,
          isArabic: false,
        ),
        returnsNormally,
      );
      expect(tripsAfter.map((t) => t.id), isNot(contains(trip.id)));
      expect(tripsBefore.length, greaterThan(tripsAfter.length));
    });
  });

  group('Stage 1.5 — Arabic validation copy', () {
    testWidgets('Arabic validation errors have no overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Directionality(
                textDirection: TextDirection.rtl,
                child: Scaffold(
                  body: Column(
                    children: [
                      Text(l10n.cashWalletValidationInvalidAmount),
                      Text(l10n.tripExchangeRatesValidationRate),
                      Text(l10n.tripExchangeRatesValidationCurrency),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('أدخل'), findsWidgets);
    });
  });
}
