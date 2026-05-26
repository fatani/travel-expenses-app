import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/design_system/calm_snackbar.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_controller.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-delete-undo',
    name: 'Bangkok',
    destination: 'Bangkok',
    baseCurrency: 'THB',
    destinationCurrency: 'THB',
    homeCurrencySnapshot: 'SAR',
  );

  final coffeeExpense = Expense.create(
    id: 'expense-coffee',
    tripId: trip.id,
    title: 'Coffee',
    amount: 120,
    currencyCode: 'THB',
    transactionAmount: 120,
    transactionCurrency: 'THB',
    convertedHomeAmount: 12.5,
    homeCurrency: 'SAR',
    conversionRate: 0.104,
    spentAt: DateTime(2026, 5, 16),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Food',
    note: 'Morning brew',
  );

  final taxiExpense = Expense.create(
    id: 'expense-taxi',
    tripId: trip.id,
    title: 'Taxi',
    amount: 250,
    currencyCode: 'THB',
    transactionAmount: 250,
    transactionCurrency: 'THB',
    spentAt: DateTime(2026, 5, 17),
    paymentMethod: 'Cash',
    paymentChannel: 'Cash',
    category: 'Transport',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  testWidgets('expense delete requires confirmation before hiding item',
      (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _openDeleteConfirmation(tester);

    expect(find.text('Delete expense?'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(repository.deletedExpenseIds, isEmpty);
  });

  testWidgets('undo restores expense without persisting delete', (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _confirmDelete(tester);
    expect(find.text('Coffee'), findsNothing);
    expect(repository.deletedExpenseIds, isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee'), findsOneWidget);
    expect(repository.deletedExpenseIds, isEmpty);
  });

  testWidgets('undo tapped twice does not duplicate delete calls', (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _confirmDelete(tester);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(repository.deletedExpenseIds, isEmpty);
    expect(find.text('Coffee'), findsOneWidget);
  });

  testWidgets('confirm hides expense but does not persist delete immediately',
      (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _confirmDelete(tester);

    expect(find.text('Coffee'), findsNothing);
    expect(find.text('Expense deleted'), findsOneWidget);
    expect(repository.deletedExpenseIds, isEmpty);
  });

  test('controller deleteExpense persists removal', () async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);
    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(expenseControllerProvider(trip.id).future);
    await container
        .read(expenseControllerProvider(trip.id).notifier)
        .deleteExpense(coffeeExpense.id);

    expect(repository.deletedExpenseIds, [coffeeExpense.id]);
    final expenses = await container.read(expenseControllerProvider(trip.id).future);
    expect(expenses, isEmpty);
  });

  test('controller deleteExpense failure surfaces error state', () async {
    final repository = _FailingDeleteExpenseRepository(expenses: [coffeeExpense]);
    final container = ProviderContainer(
      overrides: [
        expenseRepositoryProvider.overrideWithValue(repository),
        cashWalletRepositoryProvider.overrideWithValue(_NoOpCashWalletRepository()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(expenseControllerProvider(trip.id).future);

    await expectLater(
      container
          .read(expenseControllerProvider(trip.id).notifier)
          .deleteExpense(coffeeExpense.id),
      throwsA(isA<StateError>()),
    );

    expect(repository.deleteAttempts, 1);
    final state = container.read(expenseControllerProvider(trip.id));
    expect(state.hasError, isTrue);
  });

  testWidgets('filtered delete undo keeps list stable when item still matches',
      (tester) async {
    final expenses = List<Expense>.generate(
      6,
      (index) => Expense.create(
        id: 'expense-$index',
        tripId: trip.id,
        title: index == 0 ? 'Coffee shop' : 'Snack $index',
        amount: 50.0 + index,
        currencyCode: 'THB',
        transactionAmount: 50.0 + index,
        transactionCurrency: 'THB',
        spentAt: DateTime(2026, 5, 10 + index),
        paymentMethod: 'Cash',
        paymentChannel: 'Cash',
        category: 'Food',
      ),
    );
    final repository = _TrackingExpenseRepository(expenses: expenses);

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pumpAndSettle();
    expect(find.text('Coffee shop'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Coffee shop'), findsNothing);
    expect(find.text('No matching expenses'), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Coffee shop'), findsOneWidget);
    expect(repository.deletedExpenseIds, isEmpty);
  });

  testWidgets('second delete cancels first pending delete instead of committing it',
      (tester) async {
    final repository = _TrackingExpenseRepository(
      expenses: [coffeeExpense, taxiExpense],
    );

    await tester.pumpWidget(_buildTripDetails(trip: trip, repository: repository));
    await tester.pumpAndSettle();

    await _confirmDeleteForTitle(tester, 'Taxi');
    expect(find.text('Taxi'), findsNothing);
    expect(find.text('Coffee'), findsOneWidget);

    await _confirmDeleteForTitle(tester, 'Coffee');
    await tester.pumpAndSettle();

    expect(repository.deletedExpenseIds, isEmpty);
    expect(find.text('Taxi'), findsOneWidget);
    expect(find.text('Coffee'), findsNothing);
  });

  testWidgets('trip delete requires confirmation and cancel keeps trip',
      (tester) async {
    final tripsController = _TrackingTripsController([trip]);

    await tester.pumpWidget(_buildTripsList(tripsController: tripsController));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete trip'));
    await tester.pumpAndSettle();

    expect(find.text('Delete trip?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Bangkok'), findsOneWidget);
    expect(tripsController.deletedTripIds, isEmpty);
  });

  testWidgets('trip delete confirm removes trip once', (tester) async {
    final tripsController = _TrackingTripsController([trip]);

    await tester.pumpWidget(_buildTripsList(tripsController: tripsController));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete trip').last);
    await tester.pumpAndSettle();

    expect(find.text('Bangkok'), findsNothing);
    expect(tripsController.deletedTripIds, ['trip-delete-undo']);
  });

  testWidgets('arabic delete expense dialog has no overflow', (tester) async {
    final repository = _TrackingExpenseRepository(expenses: [coffeeExpense]);

    await tester.pumpWidget(
      _buildTripDetails(
        trip: trip,
        repository: repository,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('حذف المصروف؟'), findsOneWidget);
  });

  testWidgets('CalmSnackBar.showMessage does not replace active undo snackbar',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      unawaited(
                        CalmSnackBar.showUndo(
                          context,
                          message: 'Expense deleted',
                          undoLabel: 'Undo',
                          onUndo: () {},
                        ),
                      );
                    },
                    child: const Text('Undo snack'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      CalmSnackBar.showMessage(context, message: 'Brief note');
                    },
                    child: const Text('Brief snack'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Undo snack'));
    await tester.pump();
    await tester.tap(find.text('Brief snack'));
    await tester.pump();

    expect(find.text('Expense deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Brief note'), findsNothing);
  });
}

Future<void> _openDeleteConfirmation(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await _openDeleteConfirmation(tester);
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

Future<void> _confirmDeleteForTitle(WidgetTester tester, String title) async {
  final row = find.ancestor(
    of: find.text(title),
    matching: find.byType(Row),
  );
  await tester.tap(
    find.descendant(
      of: row,
      matching: find.byIcon(Icons.more_vert_rounded),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete').last);
  await tester.pump();
}

Widget _buildTripDetails({
  required Trip trip,
  required ExpenseRepository repository,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repository),
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

Widget _buildTripsList({
  required _TrackingTripsController tripsController,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      tripsControllerProvider.overrideWith(() => tripsController),
      settingsControllerProvider.overrideWith(_FakeSettingsController.new),
      expenseRepositoryProvider.overrideWithValue(_EmptyExpenseRepository()),
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TripsListScreen(),
    ),
  );
}

class _TrackingExpenseRepository extends TestExpenseRepository {
  _TrackingExpenseRepository({required List<Expense> expenses})
      : _expenses = List<Expense>.from(expenses),
        super(AppDatabase());

  final List<Expense> _expenses;
  final List<String> deletedExpenseIds = <String>[];

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<Expense?> getExpenseById(String id) async {
    for (final expense in _expenses) {
      if (expense.id == id) {
        return expense;
      }
    }
    return null;
  }

  @override
  Future<void> deleteExpense(String id) async {
    deletedExpenseIds.add(id);
    _expenses.removeWhere((expense) => expense.id == id);
  }
}

class _FailingDeleteExpenseRepository extends _TrackingExpenseRepository {
  _FailingDeleteExpenseRepository({required super.expenses});

  int deleteAttempts = 0;

  @override
  Future<void> deleteExpense(String id) async {
    deleteAttempts++;
    throw StateError('db unavailable');
  }
}

class _TrackingTripsController extends TripsController {
  _TrackingTripsController(this._trips);

  final List<Trip> _trips;
  final List<String> deletedTripIds = <String>[];

  @override
  Future<List<Trip>> build() async => List<Trip>.from(_trips);

  @override
  Future<void> deleteTrip(String id) async {
    deletedTripIds.add(id);
    _trips.removeWhere((trip) => trip.id == id);
    state = AsyncData(List<Trip>.from(_trips));
  }
}

class _EmptyExpenseRepository extends TestExpenseRepository {
  _EmptyExpenseRepository() : super(AppDatabase());

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async => const [];
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}

class _NoOpCashWalletRepository extends CashWalletRepository {
  _NoOpCashWalletRepository() : super(AppDatabase());

  @override
  Future<void> restoreCashForDeletedExpense(Expense expense) async {}
}

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}
