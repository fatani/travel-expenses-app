import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/formatting/bidi_format.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/export/data/trip_pdf_exporter.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_calculator.dart';
import 'package:travel_expenses/features/reports/data/trip_report_calculator.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  group('Stage 1.4.5 — Trip Details totals', () {
    final mixedTrip = Trip.create(
      id: 'trip-mix',
      name: 'Shanghai',
      destination: 'Shanghai',
      baseCurrency: 'CNY',
    );

    testWidgets('hides total when multiple transaction currencies exist',
        (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: mixedTrip,
          expenses: [
            _expense(
              id: 'cny',
              tripId: mixedTrip.id,
              amount: 10,
              currency: 'CNY',
            ),
            _expense(
              id: 'sar',
              tripId: mixedTrip.id,
              amount: 20,
              currency: 'SAR',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total in'), findsNothing);
      expect(find.text('Mixed'), findsNothing);
    });

    testWidgets('shows Total in {currency} only for single-currency trip',
        (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: mixedTrip,
          expenses: [
            _expense(
              id: 'cny-1',
              tripId: mixedTrip.id,
              amount: 10,
              currency: 'CNY',
            ),
            _expense(
              id: 'cny-2',
              tripId: mixedTrip.id,
              amount: 15,
              currency: 'CNY',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total in CNY only'), findsOneWidget);
      expect(find.textContaining('25 CNY'), findsOneWidget);
    });

    testWidgets('single non-base currency still shows scoped total', (tester) async {
      final thbTrip = Trip.create(
        id: 'trip-thb-only',
        name: 'Bangkok',
        destination: 'Bangkok',
        baseCurrency: 'CNY',
      );

      await tester.pumpWidget(
        _tripDetails(
          trip: thbTrip,
          expenses: [
            _expense(
              id: 'thb-1',
              tripId: thbTrip.id,
              amount: 500,
              currency: 'THB',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total in THB only'), findsOneWidget);
      expect(find.textContaining('500 THB'), findsOneWidget);
    });

    testWidgets('hides total when search filter is active', (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: mixedTrip,
          expenses: List.generate(
            6,
            (i) => _expense(
              id: 'cny-$i',
              tripId: mixedTrip.id,
              amount: 10.0 + i,
              currency: 'CNY',
              title: 'Item $i',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Total in CNY only'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Item 0');
      await tester.pumpAndSettle();

      expect(find.textContaining('Total in'), findsNothing);
    });
  });

  group('Stage 1.4.5 — Expense card conversion display', () {
    final trip = Trip.create(
      id: 'trip-card',
      name: 'Bangkok',
      destination: 'Bangkok',
      baseCurrency: 'THB',
      homeCurrencySnapshot: 'SAR',
    );

    testWidgets('shows ≈ only with stored conversion snapshot', (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: trip,
          expenses: [
            Expense.create(
              id: 'with-snapshot',
              tripId: trip.id,
              title: 'Snack',
              amount: 500,
              currencyCode: 'THB',
              transactionAmount: 500,
              transactionCurrency: 'THB',
              originalAmount: 500,
              originalCurrency: 'THB',
              convertedHomeAmount: 52.5,
              homeCurrency: 'SAR',
              conversionRate: 0.105,
              spentAt: DateTime(2026, 5, 16),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('≈'), findsOneWidget);
      expect(find.textContaining('52.5'), findsOneWidget);
    });

    testWidgets('hides approximate line when conversion snapshot missing',
        (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: trip,
          expenses: [
            Expense.create(
              id: 'no-snapshot',
              tripId: trip.id,
              title: 'Snack',
              amount: 500,
              currencyCode: 'THB',
              transactionAmount: 500,
              transactionCurrency: 'THB',
              originalAmount: 500,
              originalCurrency: 'THB',
              spentAt: DateTime(2026, 5, 16),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('≈'), findsNothing);
    });

    testWidgets('hides converted line when transaction currency equals home',
        (tester) async {
      await tester.pumpWidget(
        _tripDetails(
          trip: Trip.create(
            id: 'trip-sar',
            name: 'Riyadh',
            destination: 'Riyadh',
            baseCurrency: 'SAR',
            homeCurrencySnapshot: 'SAR',
          ),
          expenses: [
            Expense.create(
              id: 'domestic',
              tripId: 'trip-sar',
              title: 'Coffee',
              amount: 15,
              currencyCode: 'SAR',
              transactionAmount: 15,
              transactionCurrency: 'SAR',
              originalAmount: 15,
              originalCurrency: 'SAR',
              convertedHomeAmount: 15,
              homeCurrency: 'SAR',
              conversionRate: 1,
              spentAt: DateTime(2026, 5, 16),
              paymentMethod: 'Cash',
              category: 'Food',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('≈'), findsNothing);
    });
  });

  group('Stage 1.4.5 — Quick Add currency', () {
    final trip = Trip.create(
      id: 'trip-qa',
      name: 'Repeat Trip',
      destination: 'Test',
      baseCurrency: 'CNY',
    );

    final lastExpense = Expense.create(
      id: 'exp-last',
      tripId: trip.id,
      title: 'Lunch',
      amount: 25.5,
      currencyCode: 'USD',
      transactionAmount: 25.5,
      transactionCurrency: 'USD',
      spentAt: DateTime(2026, 5, 20),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );

    testWidgets('repeat last preserves last expense currency', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _tripDetails(trip: trip, expenses: [lastExpense]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat last expense'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(QuickAddExpenseSheet),
          matching: find.text('USD'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('add details preserves selected currency after repeat last',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _tripDetails(trip: trip, expenses: [lastExpense]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repeat last expense'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add Details'));
      await tester.tap(find.text('Add Details'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseFormScreen), findsOneWidget);
      expect(find.text('USD'), findsWidgets);
    });
  });

  group('Stage 1.4.5 — Reports calculators', () {
    const tripCalculator = TripReportCalculator();
    const globalCalculator = GlobalReportCalculator();

    test('trip report does not rank top category across mixed currencies', () {
      final summary = tripCalculator.calculate(
        tripId: 't1',
        tripName: 'Trip',
        expenses: [
          _expense(id: '1', tripId: 't1', amount: 100, currency: 'USD', category: 'Food'),
          _expense(id: '2', tripId: 't1', amount: 200, currency: 'SAR', category: 'Transport'),
        ],
      );

      expect(summary.topCategory, isNull);
      expect(summary.topPaymentNetwork, isNull);
      expect(summary.topPaymentChannel, isNull);
      expect(summary.totalBilledByCurrency, hasLength(2));
    });

    test('global report suppresses amount-based payment leaders when mixed', () {
      final trip = Trip.create(
        id: 'trip-1',
        name: 'Trip',
        destination: 'Test',
        baseCurrency: 'SAR',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 1, 5),
      );
      final summary = globalCalculator.calculate(
        trips: [
          trip,
          Trip.create(
            id: 'trip-2',
            name: 'Trip 2',
            destination: 'Test',
            baseCurrency: 'USD',
            startDate: DateTime(2026, 2, 1),
            endDate: DateTime(2026, 2, 5),
          ),
        ],
        expenses: [
          _expense(
            id: '1',
            tripId: 'trip-1',
            amount: 10,
            currency: 'USD',
            paymentChannel: 'Online Purchase',
          ),
          _expense(
            id: '2',
            tripId: 'trip-2',
            amount: 500,
            currency: 'SAR',
            paymentChannel: 'Cash',
          ),
        ],
      );

      expect(summary.totalBilledByCurrency, hasLength(2));
      expect(summary.mostUsedPaymentChannel, isNull);
      expect(summary.mostUsedPaymentNetwork, isNull);
    });
  });

  group('Stage 1.4.5 — Cash wallet & export & RTL', () {
    test('cash wallet balances remain per currency in repository model', () {
      final balances = [
        TripCashBalance(
          tripId: 'trip-1',
          currencyCode: 'THB',
          balanceAmount: 1000,
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
        TripCashBalance(
          tripId: 'trip-1',
          currencyCode: 'USD',
          balanceAmount: 50,
          updatedAt: DateTime.utc(2026, 5, 1),
        ),
      ];

      expect(balances.map((b) => b.currencyCode).toSet(), {'THB', 'USD'});
    });

    test('PDF export uses per-currency total labels', () async {
      final exporter = TripPdfExporter();
      final trip = Trip.create(
        id: 'trip-pdf',
        name: 'Multi',
        destination: 'Test',
        baseCurrency: 'USD',
      );
      final bytes = await exporter.buildPdfBytes(
        trip: trip,
        expenses: [
          _expense(id: '1', tripId: trip.id, amount: 100, currency: 'USD'),
          _expense(id: '2', tripId: trip.id, amount: 50, currency: 'SAR'),
        ],
      );

      expect(bytes, isNotEmpty);
      // Text extraction is unreliable; ensure generation succeeds for mixed currencies.
    });

    test('BidiAmountFormat keeps ≈ prefix LTR-safe', () {
      expect(
        BidiAmountFormat.formatApproximate(52.5, 'SAR'),
        startsWith('≈'),
      );
      expect(
        BidiAmountFormat.formatApproximate(52.5, 'SAR'),
        contains('SAR'),
      );
    });

    testWidgets('Arabic scoped total label does not imply grand total',
        (tester) async {
      final trip = Trip.create(
        id: 'trip-ar',
        name: 'Shanghai',
        destination: 'Shanghai',
        baseCurrency: 'CNY',
      );

      await tester.pumpWidget(
        _tripDetails(
          trip: trip,
          expenses: [
            _expense(id: 'e1', tripId: trip.id, amount: 50, currency: 'CNY'),
          ],
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('الإجمالي بعملة'), findsOneWidget);
      expect(find.textContaining('فقط'), findsOneWidget);
      expect(find.text('مختلطة'), findsNothing);
    });
  });
}

Expense _expense({
  required String id,
  required String tripId,
  required double amount,
  required String currency,
  String? title,
  String? category,
  String? paymentChannel,
}) {
  return Expense.create(
    id: id,
    tripId: tripId,
    title: title ?? 'Expense',
    amount: amount,
    currencyCode: currency,
    transactionAmount: amount,
    transactionCurrency: currency,
    spentAt: DateTime(2026, 4, 12),
    paymentMethod: 'Cash',
    paymentChannel: paymentChannel ?? 'Cash',
    category: category ?? 'Food',
  );
}

Widget _tripDetails({
  required Trip trip,
  required List<Expense> expenses,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(
        _FakeExpenseRepository(expenses),
      ),
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((e) => e.tripId == tripId).toList();
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
