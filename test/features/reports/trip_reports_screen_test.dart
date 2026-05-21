import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

Trip _trip() {
  return Trip.create(
    id: 'trip-1',
    name: 'Test Trip',
    destination: 'Riyadh',
    baseCurrency: 'SAR',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 3),
  );
}

Expense _expense({
  required String tripId,
  required double amount,
  required String currency,
  String? category,
  String? paymentNetwork,
  String? paymentChannel,
}) {
  return Expense.create(
    tripId: tripId,
    title: 'Expense',
    amount: amount,
    currencyCode: currency,
    category: category,
    paymentMethod: 'Card',
    paymentNetwork: paymentNetwork,
    paymentChannel: paymentChannel,
  );
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required Trip trip,
  required List<Expense> expenses,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          _FakeExpenseRepository(expenses),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: TripReportsScreen(trip: trip),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hides all breakdown sections when there is only one expense', (
    tester,
  ) async {
    final trip = _trip();
    final expenses = [
      _expense(
        tripId: trip.id,
        amount: 100,
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.textContaining('recorded 1 expense'), findsOneWidget);
    expect(find.text('Add more expenses to see clearer spending patterns.'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Total expenses'), findsNothing);
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('By category'), findsNothing);
    expect(find.textContaining('transaction currency'), findsNothing);
    expect(find.text('By payment network'), findsNothing);
    expect(find.text('By payment channel'), findsNothing);
  });

  testWidgets('hides redundant sections for two expenses with same grouping values', (
    tester,
  ) async {
    final trip = _trip();
    final expenses = [
      _expense(
        tripId: trip.id,
        amount: 100,
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 50,
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.textContaining('recorded 2 expenses'), findsOneWidget);
    expect(find.text('Add more expenses to see clearer spending patterns.'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Total expenses'), findsNothing);
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('By category'), findsNothing);
    expect(find.textContaining('transaction currency'), findsNothing);
    expect(find.text('By payment network'), findsNothing);
    expect(find.text('By payment channel'), findsNothing);
  });

  testWidgets('keeps lightweight mode when three expenses are mixed', (tester) async {
    final trip = _trip();
    final expenses = [
      _expense(
        tripId: trip.id,
        amount: 100,
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 80,
        currency: 'USD',
        category: 'Transport',
        paymentNetwork: 'Mada',
        paymentChannel: 'Online Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 40,
        currency: 'SAR',
        category: 'Shopping',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.textContaining('recorded 3 expenses'), findsOneWidget);
    expect(find.text('Add more expenses to see clearer spending patterns.'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Total expenses'), findsNothing);
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('By category'), findsNothing);
    expect(find.textContaining('transaction currency'), findsNothing);
    expect(find.text('By payment network'), findsNothing);
    expect(find.text('By payment method'), findsNothing);
    expect(find.text('By payment channel'), findsNothing);
  });

  testWidgets('shows richer breakdown sections when five expenses are mixed', (tester) async {
    final trip = _trip();
    final expenses = [
      _expense(
        tripId: trip.id,
        amount: 100,
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 80,
        currency: 'USD',
        category: 'Transport',
        paymentNetwork: 'Mada',
        paymentChannel: 'Online Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 40,
        currency: 'SAR',
        category: 'Shopping',
        paymentNetwork: 'Visa',
        paymentChannel: 'POS Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 35,
        currency: 'EUR',
        category: 'Food',
        paymentNetwork: 'Mastercard',
        paymentChannel: 'Online Purchase',
      ),
      _expense(
        tripId: trip.id,
        amount: 25,
        currency: 'SAR',
        category: 'Transport',
        paymentNetwork: 'Mada',
        paymentChannel: 'ATM Withdrawal',
      ),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('Overall spending'), findsNothing);
    expect(find.textContaining('only'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('By category'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -760));
    await tester.pumpAndSettle();

    expect(find.textContaining('transaction currency'), findsOneWidget);
    expect(find.text('By payment network'), findsOneWidget);
  });

  testWidgets('Trip report never shows behavioral smart summary', (
    tester,
  ) async {
    final trip = _trip();

    final expenses = [
      Expense.create(
        tripId: trip.id,
        title: 'Expense 1',
        amount: 300,
        currencyCode: 'SAR',
        transactionAmount: 80,
        transactionCurrency: 'USD',
        billedAmount: 300,
        billedCurrency: 'SAR',
        feesAmount: 5,
        feesCurrency: 'SAR',
        isInternational: true,
        paymentMethod: 'Card',
        paymentNetwork: 'Visa',
        paymentChannel: 'Online Purchase',
        category: 'Food',
      ),
      Expense.create(
        tripId: trip.id,
        title: 'Expense 2',
        amount: 120,
        currencyCode: 'SAR',
        paymentMethod: 'Card',
        paymentNetwork: 'Mada',
        paymentChannel: 'POS Purchase',
        category: 'Transport',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FakeExpenseRepository(expenses),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: TripReportsScreen(trip: trip),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('ملخص ذكي'), findsNothing);
    expect(find.textContaining('أغلب'), findsNothing);
    expect(find.textContaining('عادة'), findsNothing);
    expect(find.textContaining('سلوكك'), findsNothing);
    expect(find.textContaining('تميل'), findsNothing);
  });
}
