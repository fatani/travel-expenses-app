import 'package:sqflite/sqflite.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/export/presentation/export_menu.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-nav-reliability',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final sampleExpense = Expense.create(
    id: 'expense-nav',
    tripId: trip.id,
    title: 'Coffee',
    amount: 50,
    currencyCode: 'THB',
    transactionAmount: 50,
    transactionCurrency: 'THB',
    spentAt: DateTime(2026, 5, 16),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  Finder quickAddAmountField() {
    return find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
  }

  testWidgets('repeated FAB taps open only one quick add sheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsHarness(trip: trip, expenses: [sampleExpense]),
    );
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    await tester.ensureVisible(fab);
    await tester.tap(fab, warnIfMissed: false);
    await tester.tap(fab, warnIfMissed: false);
    await tester.pump();

    expect(find.byType(QuickAddExpenseSheet), findsOneWidget);
  });

  testWidgets('quick add save completing after sheet dismiss does not crash',
      (tester) async {
    final repository = _SlowCreateExpenseRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: QuickAddExpenseSheet(trip: trip, expenses: const []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(quickAddAmountField(), '25');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(tester.takeException(), isNull);
    expect(repository.createCalls, lessThanOrEqualTo(1));
  });

  testWidgets('expense delete undo snackbar after leaving screen does not crash',
      (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [sampleExpense]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
          cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => TripDetailsScreen(trip: trip),
                        ),
                      );
                    },
                    child: const Text('Open trip'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Expense deleted'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('trip card rapid taps push trip details only once', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripsListHarness(trips: [trip]),
    );
    await tester.pumpAndSettle();

    final cardTapTarget = find.byType(InkWell).first;
    await tester.ensureVisible(cardTapTarget);
    await tester.tap(cardTapTarget, warnIfMissed: false);
    await tester.tap(cardTapTarget, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('export completion after route pop does not show snackbar crash',
      (tester) async {
    final repository = _SlowListExpenseRepository([sampleExpense]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(
                        handleTripExport(
                          context,
                          ref,
                          trip: trip,
                          format: TripExportFormat.csv,
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Export and leave'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export and leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Widget _buildTripDetailsHarness({
  required Trip trip,
  List<Expense> expenses = const [],
  ExpenseRepository? repository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(
        repository ?? _StaticExpenseRepository(expenses),
      ),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TripDetailsScreen(trip: trip),
    ),
  );
}

Widget _buildTripsListHarness({required List<Trip> trips}) {
  return ProviderScope(
    overrides: [
      tripsControllerProvider.overrideWith(
        () => _StaticTripsController(trips),
      ),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
      expenseRepositoryProvider.overrideWithValue(_StaticExpenseRepository(const [])),
      cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TripsListScreen(),
    ),
  );
}

class _StaticExpenseRepository extends TestExpenseRepository {
  _StaticExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((e) => e.tripId == tripId).toList();
  }
}

class _SlowCreateExpenseRepository extends _StaticExpenseRepository {
  _SlowCreateExpenseRepository() : super(const []);

  int createCalls = 0;

  @override
  Future<Expense> createExpense(Expense expense, {DatabaseExecutor? txn}) async {
    createCalls++;
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _expenses.add(expense);
    return expense;
  }
}

class _SlowListExpenseRepository extends _StaticExpenseRepository {
  _SlowListExpenseRepository(super.expenses);

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return super.getExpensesByTrip(tripId);
  }
}

class _TrackingExpenseRepository extends _StaticExpenseRepository {
  _TrackingExpenseRepository({required List<Expense> expenses})
      : super(List<Expense>.from(expenses));

  final List<String> deletedExpenseIds = <String>[];

  @override
  Future<void> deleteExpense(String id) async {
    deletedExpenseIds.add(id);
  }
}

class _StaticTripsController extends TripsController {
  _StaticTripsController(this._trips);

  final List<Trip> _trips;

  @override
  Future<List<Trip>> build() async => List<Trip>.from(_trips);
}

class _NoOpCashWalletRepository extends CashWalletRepository {
  _NoOpCashWalletRepository() : super(AppDatabase());
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}
