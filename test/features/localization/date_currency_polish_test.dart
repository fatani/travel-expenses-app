import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final now = DateTime.now();

  final activeTrip = Trip.create(
    id: 'trip-active',
    name: 'Tokyo',
    destination: 'Tokyo',
    baseCurrency: 'JPY',
    startDate: now.subtract(const Duration(days: 2)),
    endDate: now.add(const Duration(days: 5)),
  );

  final completedTrip = Trip.create(
    id: 'trip-done',
    name: 'Paris',
    destination: 'Paris',
    baseCurrency: 'EUR',
    startDate: DateTime(2026, 5, 12),
    endDate: DateTime(2026, 5, 18),
  );

  final conversionTrip = Trip.create(
    id: 'trip-thb',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final convertedExpense = Expense.create(
    id: 'exp-conv',
    tripId: conversionTrip.id,
    title: 'Street food',
    amount: 500,
    currencyCode: 'THB',
    transactionAmount: 500,
    transactionCurrency: 'THB',
    originalAmount: 500,
    originalCurrency: 'THB',
    convertedHomeAmount: 52.5,
    homeCurrency: 'SAR',
    conversionRate: 0.105,
    spentAt: DateTime(2026, 5, 16, 14, 30),
    paymentMethod: 'Cash',
    category: 'Food',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  testWidgets('trip list shows compact active and completed date phrases',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip, completedTrip]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Day 3 of'), findsOneWidget);
    expect(find.textContaining('12–18 May'), findsOneWidget);
    expect(find.textContaining('ends '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expense card shows approximate conversion with ≈ and no FX rate',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: conversionTrip,
        expenses: [convertedExpense],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('≈'), findsOneWidget);
    expect(find.textContaining('1 THB ='), findsNothing);
    expect(find.textContaining('0.105'), findsNothing);
  });

  testWidgets('single-currency subtle total uses per-currency label', (tester) async {
    final trip = Trip.create(
      id: 'trip-cny',
      name: 'Shanghai',
      destination: 'Shanghai',
      baseCurrency: 'CNY',
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenses: [
          Expense.create(
            id: 'e1',
            tripId: trip.id,
            title: 'Lunch',
            amount: 10,
            currencyCode: 'CNY',
            transactionAmount: 10,
            transactionCurrency: 'CNY',
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Cash',
            category: 'Food',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Total in CNY only'), findsOneWidget);
    expect(find.textContaining('Total expenses:'), findsNothing);
  });

  testWidgets('multi-currency trip hides combined total', (tester) async {
    final trip = Trip.create(
      id: 'trip-mix',
      name: 'Shanghai',
      destination: 'Shanghai',
      baseCurrency: 'CNY',
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenses: [
          Expense.create(
            id: 'e1',
            tripId: trip.id,
            title: 'Lunch',
            amount: 10,
            currencyCode: 'CNY',
            transactionAmount: 10,
            transactionCurrency: 'CNY',
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Cash',
            category: 'Food',
          ),
          Expense.create(
            id: 'e2',
            tripId: trip.id,
            title: 'Taxi',
            amount: 20,
            currencyCode: 'SAR',
            transactionAmount: 20,
            transactionCurrency: 'SAR',
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Cash',
            category: 'Transport',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Total in'), findsNothing);
    expect(find.text('Mixed'), findsNothing);
  });

  testWidgets('arabic trip list date phrases avoid overflow', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(
        trips: [activeTrip],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('يوم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add shows compact currency code label', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickAddExpenseSheet(
            trip: activeTrip,
            expenses: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(QuickAddExpenseSheet),
        matching: find.text('JPY ▼'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Amount in'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildTripsListApp({
  required List<Trip> trips,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      tripsControllerProvider.overrideWith(
        () => _FakeTripsController(trips),
      ),
      settingsControllerProvider.overrideWith(
        _FakeSettingsController.new,
      ),
      cashWalletRepositoryProvider.overrideWithValue(
        _EmptyCashWalletRepository(),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TripsListScreen(),
    ),
  );
}

Widget _buildTripDetailsApp({
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

class _FakeTripsController extends TripsController {
  _FakeTripsController(this._trips);

  final List<Trip> _trips;

  @override
  Future<List<Trip>> build() async => _trips;
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(this._expenses)
      : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((e) => e.tripId == tripId).toList();
  }
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}
