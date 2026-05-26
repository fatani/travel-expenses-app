import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/cash_wallet/presentation/trip_cash_wallet_screen.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/export/presentation/export_menu.dart';
import 'package:travel_expenses/features/global_reports/presentation/global_reports_screen.dart';
import 'package:travel_expenses/features/reports/presentation/trip_reports_screen.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/data/trip_repository.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';
import 'package:travel_expenses/shared/widgets/calm_load_error_panel.dart';

Trip _trip({String id = 'trip-1'}) {
  return Trip.create(
    id: id,
    name: 'Tokyo',
    destination: 'Tokyo',
    baseCurrency: 'JPY',
    startDate: DateTime(2026, 1, 1),
    endDate: DateTime(2026, 1, 10),
  );
}

Expense _expense(String tripId) {
  return Expense.create(
    tripId: tripId,
    title: 'Lunch',
    amount: 12,
    currencyCode: 'JPY',
    category: 'Food',
    paymentMethod: 'Cash',
  );
}

Widget _app({
  required Widget home,
  List<Override> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _StubTripRepository extends TripRepository {
  _StubTripRepository(this._trip) : super(AppDatabase());

  final Trip _trip;

  @override
  Future<Trip?> getTripById(String id) async {
    return id == _trip.id ? _trip : null;
  }
}

class _ThrowingTripRepository extends TripRepository {
  _ThrowingTripRepository() : super(AppDatabase());

  @override
  Future<List<Trip>> getTrips() async {
    throw Exception('SqliteException(database is locked)');
  }
}

class _FailOnSecondTripsRepository extends TripRepository {
  _FailOnSecondTripsRepository(this._trips) : super(AppDatabase());

  final List<Trip> _trips;
  var _calls = 0;

  @override
  Future<List<Trip>> getTrips() async {
    _calls++;
    if (_calls == 1) {
      return _trips;
    }
    throw Exception('SqliteException(disk I/O error)');
  }
}

class _ThrowingExpenseRepository extends TestExpenseRepository {
  _ThrowingExpenseRepository() : super(AppDatabase());

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    throw Exception('SqliteException(no such table)');
  }
}

class _DelayedThrowingExpenseRepository extends TestExpenseRepository {
  _DelayedThrowingExpenseRepository() : super(AppDatabase());

  final Completer<void> gate = Completer<void>();
  int calls = 0;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    calls++;
    await gate.future;
    throw Exception('SqliteException(database is locked)');
  }
}

class _FailOnSecondExpenseRepository extends TestExpenseRepository {
  _FailOnSecondExpenseRepository(this._expenses) : super(AppDatabase());

  final List<Expense> _expenses;
  var _calls = 0;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    _calls++;
    if (_calls == 1) {
      return _expenses;
    }
    throw Exception('SqliteException(readonly database)');
  }
}

class _ThrowingCashWalletRepository extends CashWalletRepository {
  _ThrowingCashWalletRepository() : super(AppDatabase());

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    throw Exception('SqliteException(database is locked)');
  }

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async {
    throw Exception('SqliteException(database is locked)');
  }
}

class _FailOnSecondCashWalletRepository extends CashWalletRepository {
  _FailOnSecondCashWalletRepository() : super(AppDatabase());

  var _balanceLoads = 0;

  @override
  Future<List<TripCashBalance>> getBalancesByTrip(String tripId) async {
    _balanceLoads++;
    if (_balanceLoads == 1) {
      return [
        TripCashBalance(
          tripId: tripId,
          currencyCode: 'JPY',
          balanceAmount: 5000,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];
    }
    throw Exception('SqliteException(database is locked)');
  }

  @override
  Future<List<CashTransaction>> getRecentTransactionsByTrip(
    String tripId, {
    int limit = 20,
    bool includeReversed = false,
  }) async =>
      const [];
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  testWidgets('trips load failure shows calm error without raw exception text',
      (tester) async {
    await tester.pumpWidget(
      _app(
        home: const TripsListScreen(),
        overrides: [
          tripRepositoryProvider.overrideWithValue(_ThrowingTripRepository()),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load trips."), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('trips reload failure keeps stale list visible', (tester) async {
    await tester.pumpWidget(
      _app(
        home: const TripsListScreen(),
        overrides: [
          tripRepositoryProvider.overrideWithValue(
            _FailOnSecondTripsRepository([_trip()]),
          ),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tokyo'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tokyo'), findsOneWidget);
    expect(find.text("Couldn't load trips."), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('trip details load failure is calm and not fake empty',
      (tester) async {
    final trip = _trip();
    await tester.pumpWidget(
      _app(
        home: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _ThrowingExpenseRepository(),
          ),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load expenses."), findsWidgets);
    expect(find.textContaining('SqliteException'), findsNothing);
    expect(find.text('No expenses yet'), findsNothing);
  });

  testWidgets('trip details stale data survives failed reload', (tester) async {
    final trip = _trip();
    await tester.pumpWidget(
      _app(
        home: TripDetailsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _FailOnSecondExpenseRepository([_expense(trip.id)]),
          ),
          cashWalletRepositoryProvider.overrideWithValue(
            _EmptyCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lunch'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Lunch'), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('cash wallet load failure shows retry and no infinite spinner',
      (tester) async {
    final trip = _trip();
    await tester.pumpWidget(
      _app(
        home: TripCashWalletScreen(trip: trip),
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(
            _ThrowingCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load cash wallet."), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('cash wallet refresh failure keeps prior balance visible',
      (tester) async {
    final trip = _trip();
    await tester.pumpWidget(
      _app(
        home: TripCashWalletScreen(trip: trip),
        overrides: [
          cashWalletRepositoryProvider.overrideWithValue(
            _FailOnSecondCashWalletRepository(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('JPY'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("Couldn't load cash wallet."), findsOneWidget);
    expect(find.text('JPY'), findsWidgets);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('trip reports load failure is calm with retry', (tester) async {
    final trip = _trip();
    await tester.pumpWidget(
      _app(
        home: TripReportsScreen(trip: trip),
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _ThrowingExpenseRepository(),
          ),
          tripRepositoryProvider.overrideWithValue(_StubTripRepository(trip)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load this report."), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('global reports load failure is calm with retry', (tester) async {
    await tester.pumpWidget(
      _app(
        home: const GlobalReportsScreen(),
        overrides: [
          tripRepositoryProvider.overrideWithValue(_ThrowingTripRepository()),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text("Couldn't load the summary report."), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('export failure shows calm message without exception text',
      (tester) async {
    final trip = _trip();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(
            _ThrowingExpenseRepository(),
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
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => handleTripExport(
                      context,
                      ref,
                      trip: trip,
                      format: TripExportFormat.csv,
                    ),
                    child: const Text('Export'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't export CSV"), findsOneWidget);
    expect(find.textContaining('SqliteException'), findsNothing);
  });

  testWidgets('rapid export taps trigger a single in-flight operation and recover',
      (tester) async {
    final trip = _trip();
    final repository = _DelayedThrowingExpenseRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseRepositoryProvider.overrideWithValue(repository),
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
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => handleTripExport(
                      context,
                      ref,
                      trip: trip,
                      format: TripExportFormat.csv,
                    ),
                    child: const Text('Export'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(repository.calls, 1);

    repository.gate.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pump();

    expect(repository.calls, 2);
  });

  testWidgets('arabic error panel has no overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _app(
        locale: const Locale('ar'),
        home: Scaffold(
          body: CalmLoadErrorPanel(
            title: 'تعذر تحميل الرحلات.',
            retryLabel: 'إعادة المحاولة',
            onRetry: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
  });
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}

void _noop() {}

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
