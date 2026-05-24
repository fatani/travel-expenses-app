import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate.dart';
import 'package:travel_expenses/core/finance/manual_exchange_rate_repository.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_form_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final tripMissingDates = Trip.create(
    id: 'trip-missing-dates',
    name: 'Riyadh',
    destination: 'Riyadh',
    baseCurrency: 'SAR',
  );

  testWidgets('tapping missing dates warning opens trip editor', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        trip: tripMissingDates,
        expenseRepository: _FakeExpenseRepository(initialExpenses: const []),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dates need attention'), findsOneWidget);
    expect(find.text('Set start and end dates'), findsOneWidget);

    await tester.tap(find.text('Set start and end dates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TripFormScreen), findsOneWidget);
    expect(find.text('Edit Trip'), findsOneWidget);
  });

  testWidgets('expenses load error shows friendly message not raw error',
      (tester) async {
    const technicalError = 'SqliteException: no such table: expenses';

    await tester.pumpWidget(
      _buildApp(
        trip: tripMissingDates,
        expenseRepository: _ThrowingExpenseRepository(technicalError),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong while loading expenses.'),
      findsOneWidget,
    );
    expect(find.text(technicalError), findsNothing);
    expect(find.text('Could not load expenses.'), findsOneWidget);
  });
}

Widget _buildApp({
  required Trip trip,
  required ExpenseRepository expenseRepository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(expenseRepository),
      cashWalletRepositoryProvider.overrideWithValue(_FakeCashWalletRepository()),
      manualExchangeRateRepositoryProvider.overrideWithValue(
        _FakeManualExchangeRateRepository(),
      ),
      tripRepositoryProvider.overrideWithValue(_FakeTripRepository(trip)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _ThrowingExpenseRepository extends ExpenseRepository {
  _ThrowingExpenseRepository(this.message) : super(AppDatabase());

  final String message;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    throw Exception(message);
  }
}

class _FakeTripRepository extends TripRepository {
  _FakeTripRepository(this.trip) : super(AppDatabase());

  final Trip trip;

  @override
  Future<Trip?> getTripById(String id) async => trip;
}

class _FakeManualExchangeRateRepository extends ManualExchangeRateRepository {
  _FakeManualExchangeRateRepository() : super(AppDatabase());

  @override
  Future<List<ManualExchangeRate>> listLatestTripRates(String tripId) async =>
      const [];
}

class _FakeCashWalletRepository extends CashWalletRepository {
  _FakeCashWalletRepository() : super(AppDatabase());

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async =>
      const [];

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      const [];
}
