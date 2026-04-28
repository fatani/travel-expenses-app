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

Trip _trip({
  String id = 'trip-1',
  String baseCurrency = 'SAR',
  double? budget,
  String? budgetCurrency,
  DateTime? startDate,
  DateTime? endDate,
}) {
  return Trip.create(
    id: id,
    name: 'Test Trip',
    destination: 'Riyadh',
    baseCurrency: baseCurrency,
    budget: budget,
    budgetCurrency: budgetCurrency,
    startDate: startDate ?? DateTime(2026, 1, 1),
    endDate: endDate ?? DateTime(2026, 1, 3),
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
  testWidgets(
    'shows prediction section for ended trip with enough data and hides forecast row',
    (tester) async {
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
          amount: 90,
          currency: 'SAR',
          category: 'Transport',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: trip.id,
          amount: 80,
          currency: 'SAR',
          category: 'Shopping',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: trip.id,
          amount: 120,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
        _expense(
          tripId: trip.id,
          amount: 110,
          currency: 'SAR',
          category: 'Food',
          paymentNetwork: 'Visa',
          paymentChannel: 'POS Purchase',
        ),
      ];

      await _pumpReport(tester, trip: trip, expenses: expenses);

      expect(find.text('📊 ملخص الصرف والتوصيات'), findsOneWidget);
      expect(find.text('أنفقت حتى الآن'), findsOneWidget);
      expect(find.text('معدل الصرف اليومي'), findsOneWidget);
      expect(find.text('المتوقع بنهاية الرحلة'), findsNothing);
    },
  );

  testWidgets('shows full prediction section for ongoing trip', (tester) async {
    final trip = Trip.create(
      id: 'trip-2',
      name: 'Active Trip',
      destination: 'Riyadh',
      baseCurrency: 'SAR',
      startDate: DateTime.now().subtract(const Duration(days: 26)),
      endDate: DateTime.now().add(const Duration(days: 2)),
    );
    final expenses = [
      _expense(tripId: trip.id, amount: 100, currency: 'SAR', category: 'Food'),
      _expense(
        tripId: trip.id,
        amount: 90,
        currency: 'SAR',
        category: 'Transport',
      ),
      _expense(
        tripId: trip.id,
        amount: 80,
        currency: 'SAR',
        category: 'Shopping',
      ),
      _expense(tripId: trip.id, amount: 120, currency: 'SAR', category: 'Food'),
      _expense(tripId: trip.id, amount: 110, currency: 'SAR', category: 'Food'),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.text('📊 التوقعات والتوصيات'), findsOneWidget);
    expect(find.text('المتوقع بنهاية الرحلة'), findsOneWidget);
    expect(find.text('باقي 2 أيام على نهاية الرحلة'), findsOneWidget);
  });

  testWidgets('does not show budget guardrails when trip has no budget', (
    tester,
  ) async {
    final trip = _trip();
    final expenses = [
      _expense(tripId: trip.id, amount: 120, currency: 'SAR', category: 'Food'),
      _expense(
        tripId: trip.id,
        amount: 90,
        currency: 'SAR',
        category: 'Transport',
      ),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.text('Budget guardrails'), findsNothing);
  });

  testWidgets(
    'shows exceeded budget warning when current spend is above budget',
    (tester) async {
      final trip = _trip(budget: 300, budgetCurrency: 'SAR');
      final expenses = [
        _expense(
          tripId: trip.id,
          amount: 100,
          currency: 'SAR',
          category: 'Food',
        ),
        _expense(
          tripId: trip.id,
          amount: 90,
          currency: 'SAR',
          category: 'Transport',
        ),
        _expense(
          tripId: trip.id,
          amount: 80,
          currency: 'SAR',
          category: 'Shopping',
        ),
        _expense(
          tripId: trip.id,
          amount: 120,
          currency: 'SAR',
          category: 'Food',
        ),
      ];

      await _pumpReport(tester, trip: trip, expenses: expenses);

      expect(find.text('Budget guardrails'), findsOneWidget);
      expect(
        find.text('Current spending has already exceeded the trip budget.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows near-limit warning when budget usage crosses eighty percent',
    (tester) async {
      final trip = _trip(budget: 500, budgetCurrency: 'SAR');
      final expenses = [
        _expense(
          tripId: trip.id,
          amount: 150,
          currency: 'SAR',
          category: 'Food',
        ),
        _expense(
          tripId: trip.id,
          amount: 130,
          currency: 'SAR',
          category: 'Transport',
        ),
        _expense(
          tripId: trip.id,
          amount: 120,
          currency: 'SAR',
          category: 'Shopping',
        ),
      ];

      await _pumpReport(tester, trip: trip, expenses: expenses);

      expect(find.text('Budget guardrails'), findsOneWidget);
      expect(find.text('Used'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(
        find.text(
          'Budget usage is close to the limit. Review the next spending decisions carefully.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'shows safe mismatch note when budget currency differs from spending currency',
    (tester) async {
      final trip = _trip(budget: 500, budgetCurrency: 'SAR');
      final expenses = [
        _expense(
          tripId: trip.id,
          amount: 100,
          currency: 'USD',
          category: 'Food',
        ),
        _expense(
          tripId: trip.id,
          amount: 90,
          currency: 'USD',
          category: 'Transport',
        ),
        _expense(
          tripId: trip.id,
          amount: 80,
          currency: 'USD',
          category: 'Shopping',
        ),
      ];

      await _pumpReport(tester, trip: trip, expenses: expenses);

      expect(find.text('Budget guardrails'), findsOneWidget);
      expect(
        find.text(
          'Budget is set in a different currency, so usage cannot be compared safely.',
        ),
        findsOneWidget,
      );
      expect(find.text('Current spend'), findsNothing);
    },
  );

  testWidgets('shows forecast warning when projected spend will exceed budget', (
    tester,
  ) async {
    final now = DateTime.now();
    final trip = _trip(
      id: 'trip-forecast',
      budget: 700,
      budgetCurrency: 'SAR',
      startDate: now.subtract(const Duration(days: 7)),
      endDate: now.add(const Duration(days: 7)),
    );
    final expenses = [
      _expense(tripId: trip.id, amount: 100, currency: 'SAR', category: 'Food'),
      _expense(
        tripId: trip.id,
        amount: 90,
        currency: 'SAR',
        category: 'Transport',
      ),
      _expense(
        tripId: trip.id,
        amount: 80,
        currency: 'SAR',
        category: 'Shopping',
      ),
      _expense(tripId: trip.id, amount: 120, currency: 'SAR', category: 'Food'),
      _expense(tripId: trip.id, amount: 110, currency: 'SAR', category: 'Food'),
    ];

    await _pumpReport(tester, trip: trip, expenses: expenses);

    expect(find.text('Budget guardrails'), findsOneWidget);
    expect(
      find.text(
        'At the current pace, this trip is likely to exceed the budget before it ends.',
      ),
      findsOneWidget,
    );
  });

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

    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('Total billed'), findsOneWidget);
    expect(find.text('By category'), findsNothing);
    expect(find.textContaining('transaction currency'), findsNothing);
    expect(find.text('By payment network'), findsNothing);
    expect(find.text('By payment channel'), findsNothing);
  });

  testWidgets(
    'hides redundant sections for two expenses with same grouping values',
    (tester) async {
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

      expect(find.text('Total expenses'), findsOneWidget);
      expect(find.text('Total billed'), findsOneWidget);
      expect(find.text('By category'), findsNothing);
      expect(find.textContaining('transaction currency'), findsNothing);
      expect(find.text('By payment network'), findsNothing);
      expect(find.text('By payment channel'), findsNothing);
    },
  );

  testWidgets('shows breakdown sections when three expenses are mixed', (
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

    expect(find.text('Total expenses'), findsOneWidget);
    expect(find.text('Total billed'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('By category'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.textContaining('transaction currency'), findsOneWidget);
    expect(find.text('By payment network'), findsOneWidget);
    expect(find.text('By payment channel'), findsOneWidget);
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
