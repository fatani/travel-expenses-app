import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/core/theme/rtl_typography.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final now = DateTime(2026, 5, 25);

  final longArabicTrip = Trip.create(
    id: 'trip-calm-ar',
    name: 'رحلة عمل إلى المملكة العربية السعودية للمؤتمر السنوي',
    destination: 'الرياض',
    baseCurrency: 'SAR',
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 4)),
    budget: 8000,
  );

  final sampleExpense = Expense.create(
    id: 'exp-calm-ar',
    tripId: longArabicTrip.id,
    title: 'مطعم الشام',
    amount: 320,
    currencyCode: 'SAR',
    transactionAmount: 320,
    transactionCurrency: 'SAR',
    spentAt: DateTime(2026, 5, 24, 14, 30),
    paymentMethod: 'Cash',
    category: 'Food',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  testWidgets('arabic trip list has no overflow and calm title weight',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final titleFinder = find.textContaining('رحلة عمل');
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontWeight, RtlTypography.titleWeight(true));
    expect(titleText.style?.height, RtlTypography.titleLineHeight(true));
  });

  testWidgets('arabic trip details expense amount stays LTR and calm weight',
      (tester) async {
    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: longArabicTrip,
        expenses: [sampleExpense],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final amountFinder = find.text('320');
    final amountText = tester.widget<Text>(amountFinder);
    expect(amountText.style?.fontWeight, RtlTypography.amountWeight(true));

    expect(
      tester.widget<Directionality>(
        find.ancestor(
          of: amountFinder,
          matching: find.byType(Directionality),
        ).first,
      ).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('arabic quick add keeps save reachable with calm amount field',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QuickAddExpenseSheet(
            trip: longArabicTrip,
            expenses: [sampleExpense],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('حفظ'), findsOneWidget);

    final saveButton = tester.getBottomLeft(find.text('حفظ'));
    expect(saveButton.dy, greaterThan(0));

    final amountField = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountField.style?.fontWeight, RtlTypography.amountWeight(true));
    expect(amountField.textDirection, TextDirection.ltr);
  });
}

Widget _buildTripsListApp({
  required List<Trip> trips,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      tripsControllerProvider.overrideWith(() => _FakeTripsController(trips)),
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
      cardRepositoryProvider.overrideWithValue(_EmptyCardRepository()),
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

class _FakeSettingsController extends SettingsController {
  @override
  Future<AppSettings> build() async => AppSettings.defaults();
}

class _FakeExpenseRepository extends TestExpenseRepository {
  _FakeExpenseRepository(List<Expense> expenses)
      : _expenses = List<Expense>.from(expenses),
        super(AppDatabase());

  final List<Expense> _expenses;

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async =>
      _expenses.where((expense) => expense.tripId == tripId).toList();
}

class _EmptyExpenseRepository extends TestExpenseRepository {
  _EmptyExpenseRepository() : super(AppDatabase());

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async => [];
}

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
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
