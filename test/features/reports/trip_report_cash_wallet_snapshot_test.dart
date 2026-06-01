import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/reports/data/trip_cash_balances_provider.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository(this._trip) : super(AppDatabase());

  final Trip _trip;

  @override
  Future<Trip?> getTripById(String id) async {
    return id == _trip.id ? _trip : null;
  }
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository({List<TripCashBalance>? balances})
    : _balances = balances ?? const <TripCashBalance>[],
      super(AppDatabase());

  final List<TripCashBalance> _balances;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    return _balances.where((balance) => balance.tripId == tripId).toList();
  }
}

Trip _trip({DateTime? startDate, DateTime? endDate}) {
  return Trip.create(
    id: 'trip-1',
    name: 'Test Trip',
    destination: 'Riyadh',
    baseCurrency: 'SAR',
    startDate: startDate ?? DateTime(2026, 1, 1),
    endDate: endDate ?? DateTime(2026, 12, 31),
  );
}

TripCashBalance _balance({
  required String tripId,
  required String currencyCode,
  required double amount,
}) {
  return TripCashBalance(
    tripId: tripId,
    currencyCode: currencyCode,
    balanceAmount: amount,
    updatedAt: DateTime.utc(2026, 5, 1),
  );
}

Expense _expense({
  required String tripId,
  required double amount,
  required String currency,
  String? category,
  String? paymentNetwork,
  String? paymentChannel,
  DateTime? spentAt,
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
    spentAt: spentAt,
  );
}

List<Expense> _insightTriggeringExpenses(String tripId) {
  return [
    _expense(
      tripId: tripId,
      amount: 40,
      currency: 'SAR',
      category: 'Food',
      spentAt: DateTime(2026, 1, 1),
    ),
    _expense(
      tripId: tripId,
      amount: 50,
      currency: 'SAR',
      category: 'Food',
      spentAt: DateTime(2026, 1, 2),
    ),
    _expense(
      tripId: tripId,
      amount: 180,
      currency: 'SAR',
      category: 'Food',
      spentAt: DateTime(2026, 1, 3),
    ),
    _expense(
      tripId: tripId,
      amount: 200,
      currency: 'SAR',
      category: 'Food',
      spentAt: DateTime(2026, 1, 4),
    ),
    _expense(
      tripId: tripId,
      amount: 220,
      currency: 'SAR',
      category: 'Transport',
      spentAt: DateTime(2026, 1, 5),
    ),
  ];
}

List<Expense> _fiveMixedExpenses(String tripId) {
  return [
    _expense(
      tripId: tripId,
      amount: 100,
      currency: 'SAR',
      category: 'Food',
      paymentNetwork: 'Visa',
      paymentChannel: 'POS Purchase',
    ),
    _expense(
      tripId: tripId,
      amount: 80,
      currency: 'USD',
      category: 'Transport',
      paymentNetwork: 'Mada',
      paymentChannel: 'Online Purchase',
    ),
    _expense(
      tripId: tripId,
      amount: 40,
      currency: 'SAR',
      category: 'Shopping',
      paymentNetwork: 'Visa',
      paymentChannel: 'POS Purchase',
    ),
    _expense(
      tripId: tripId,
      amount: 35,
      currency: 'EUR',
      category: 'Food',
      paymentNetwork: 'Mastercard',
      paymentChannel: 'Online Purchase',
    ),
    _expense(
      tripId: tripId,
      amount: 25,
      currency: 'SAR',
      category: 'Transport',
      paymentNetwork: 'Mada',
      paymentChannel: 'ATM Withdrawal',
    ),
  ];
}

Future<void> _pumpReport(
  WidgetTester tester, {
  required Trip trip,
  required List<Expense> expenses,
  List<TripCashBalance> balances = const [],
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(
          _FakeExpenseRepository(expenses),
        ),
        tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
        cashWalletRepositoryProvider.overrideWithValue(
          _FakeCashWalletRepository(balances: balances),
        ),
      ],
      child: MaterialApp(
        locale: locale,
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
  group('tripPositiveCashBalances', () {
    test('excludes zero and negative balances', () {
      final filtered = tripPositiveCashBalances([
        _balance(tripId: 't', currencyCode: 'SAR', amount: 150),
        _balance(tripId: 't', currencyCode: 'USD', amount: 0),
        _balance(tripId: 't', currencyCode: 'JPY', amount: -5),
        _balance(tripId: 't', currencyCode: 'EUR', amount: 40),
      ]);

      expect(filtered, hasLength(2));
      expect(filtered.map((b) => b.currencyCode), ['SAR', 'EUR']);
    });
  });

  testWidgets('hides snapshot when no positive balances exist', (tester) async {
    final trip = _trip();
    await _pumpReport(
      tester,
      trip: trip,
      expenses: _fiveMixedExpenses(trip.id),
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 0),
        _balance(tripId: trip.id, currencyCode: 'USD', amount: -10),
      ],
    );

    expect(find.byKey(const Key('trip_report_cash_wallet_snapshot')), findsNothing);
    expect(find.text('Cash on hand'), findsNothing);
  });

  testWidgets('shows snapshot when positive balances exist', (tester) async {
    final trip = _trip();
    await _pumpReport(
      tester,
      trip: trip,
      expenses: _fiveMixedExpenses(trip.id),
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 150),
      ],
    );

    expect(find.byKey(const Key('trip_report_cash_wallet_snapshot')), findsOneWidget);
    expect(find.text('Cash on hand'), findsOneWidget);
    expect(find.text('150 SAR'), findsOneWidget);
  });

  testWidgets('renders multiple positive currencies without collapsing', (
    tester,
  ) async {
    final trip = _trip();
    await _pumpReport(
      tester,
      trip: trip,
      expenses: _fiveMixedExpenses(trip.id),
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 150),
        _balance(tripId: trip.id, currencyCode: 'USD', amount: 40),
        _balance(tripId: trip.id, currencyCode: 'JPY', amount: 2000),
        _balance(tripId: trip.id, currencyCode: 'EUR', amount: 0),
      ],
    );

    final snapshot = find.byKey(const Key('trip_report_cash_wallet_snapshot'));
    expect(find.descendant(of: snapshot, matching: find.text('150 SAR')), findsOneWidget);
    expect(find.descendant(of: snapshot, matching: find.text('40 USD')), findsOneWidget);
    expect(find.descendant(of: snapshot, matching: find.text('2000 JPY')), findsOneWidget);
    expect(find.descendant(of: snapshot, matching: find.textContaining('EUR')), findsNothing);
  });

  testWidgets('places snapshot before insights when insights are present', (
    tester,
  ) async {
    final trip = _trip();
    await _pumpReport(
      tester,
      trip: trip,
      expenses: _insightTriggeringExpenses(trip.id),
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 100),
      ],
    );

    expect(find.text('Notes'), findsOneWidget);
    final snapshotY = tester.getTopLeft(
      find.byKey(const Key('trip_report_cash_wallet_snapshot')),
    ).dy;
    final insightsY = tester.getTopLeft(find.text('Notes')).dy;
    expect(snapshotY, lessThan(insightsY));
  });

  testWidgets('places snapshot before predictions when insights are absent', (
    tester,
  ) async {
    final trip = _trip(
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 20)),
    );
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
        currency: 'SAR',
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
        currency: 'SAR',
        category: 'Food',
        paymentNetwork: 'Mastercard',
        paymentChannel: 'Online Purchase',
      ),
    ];

    await _pumpReport(
      tester,
      trip: trip,
      expenses: expenses,
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 50),
      ],
    );

    expect(find.text('Notes'), findsNothing);
    expect(find.text('Predictions'), findsOneWidget);
    final snapshotY = tester.getTopLeft(
      find.byKey(const Key('trip_report_cash_wallet_snapshot')),
    ).dy;
    final predictionY = tester.getTopLeft(find.text('Predictions')).dy;
    expect(snapshotY, lessThan(predictionY));
  });

  testWidgets('Arabic snapshot title and LTR currency rows', (tester) async {
    final trip = _trip();
    await _pumpReport(
      tester,
      trip: trip,
      expenses: _fiveMixedExpenses(trip.id),
      balances: [
        _balance(tripId: trip.id, currencyCode: 'SAR', amount: 150),
        _balance(tripId: trip.id, currencyCode: 'USD', amount: 40),
      ],
      locale: const Locale('ar'),
    );

    expect(find.text('النقد المتوفر'), findsOneWidget);
    expect(find.text('150 SAR'), findsOneWidget);
    expect(find.text('40 USD'), findsOneWidget);

    final ltrDirectionality = find.ancestor(
      of: find.text('USD'),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Directionality &&
            widget.textDirection == TextDirection.ltr,
      ),
    );
    expect(ltrDirectionality, findsWidgets);
  });
}
