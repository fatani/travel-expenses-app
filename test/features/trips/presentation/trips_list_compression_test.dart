import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/global_reports/presentation/global_reports_screen.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 5, 25);

  final activeTrip = Trip.create(
    id: 'trip-active',
    name: 'Tokyo',
    destination: 'Tokyo',
    baseCurrency: 'JPY',
    startDate: now.subtract(const Duration(days: 2)),
    endDate: now.add(const Duration(days: 5)),
    budget: 5000,
  );

  final completedTrip = Trip.create(
    id: 'trip-completed',
    name: 'Paris',
    destination: 'Paris',
    baseCurrency: 'EUR',
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 1, 10),
    budget: 1200,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  testWidgets('trip cards hide always-visible edit and delete icon buttons',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip, completedTrip]),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Edit trip' &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.edit_outlined,
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            widget.tooltip == 'Delete trip' &&
            widget.icon is Icon &&
            (widget.icon as Icon).icon == Icons.delete_outline_rounded,
      ),
      findsNothing,
    );
  });

  testWidgets('tapping trip card opens trip details', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(
        trips: [activeTrip],
        expenseRepository: _FakeExpenseRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tokyo'));
    await tester.pumpAndSettle();

    expect(find.byType(TripDetailsScreen), findsOneWidget);
  });

  testWidgets('edit and delete remain in trip card overflow menu', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit trip'), findsOneWidget);
    expect(find.text('Delete trip'), findsOneWidget);
  });

  testWidgets('delete from overflow still shows confirmation dialog', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete trip'));
    await tester.pumpAndSettle();

    expect(find.text('Delete trip?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(TripsListScreen), findsOneWidget);
  });

  testWidgets('trip cards do not show budget row by default', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip, completedTrip]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Budget'), findsNothing);
  });

  testWidgets('completed trip status chip uses muted foreground color',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [completedTrip]),
    );
    await tester.pumpAndSettle();

    final completedLabel = find.text('Completed');
    expect(completedLabel, findsOneWidget);

    final text = tester.widget<Text>(completedLabel);
    expect(text.style?.color, const Color(0xFF94A3B8));
    expect(text.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('app bar does not expose prominent global reports icon button',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip]),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is IconButton &&
              widget.icon is Icon &&
              (widget.icon as Icon).icon == Icons.analytics_outlined,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('global reports remains reachable from app bar overflow menu',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [activeTrip]),
    );
    await tester.pumpAndSettle();

    final appBarOverflow = find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.more_vert_rounded),
    );
    await tester.tap(appBarOverflow);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Global reports'));
    await tester.pumpAndSettle();

    expect(find.byType(GlobalReportsScreen), findsOneWidget);
  });

  testWidgets('empty state keeps one primary start trip CTA', (tester) async {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': false,
    });

    await tester.pumpWidget(
      _buildTripsListApp(trips: const []),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add trip'), findsOneWidget);
    expect(find.text('Global reports'), findsNothing);
  });

  testWidgets('arabic trip list keeps currency in LTR isolate', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(
        trips: [activeTrip],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final currencyFinder = find.text('JPY');
    expect(currencyFinder, findsOneWidget);

    final directionality = tester.widget<Directionality>(
      find.ancestor(
        of: currencyFinder,
        matching: find.byType(Directionality),
      ).first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });
}

Widget _buildTripsListApp({
  required List<Trip> trips,
  Locale locale = const Locale('en'),
  _FakeExpenseRepository? expenseRepository,
}) {
  return ProviderScope(
    overrides: [
      tripsControllerProvider.overrideWith(
        () => _FakeTripsController(trips),
      ),
      settingsControllerProvider.overrideWith(
        _FakeSettingsController.new,
      ),
      if (expenseRepository != null)
        expenseRepositoryProvider.overrideWithValue(expenseRepository),
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

class _FakeTripsController extends TripsController {
  _FakeTripsController(this._trips);

  final List<Trip> _trips;

  @override
  Future<List<Trip>> build() async => _trips;
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());

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
