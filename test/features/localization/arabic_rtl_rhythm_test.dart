import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/formatting/bidi_format.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
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

DateTime _activeTripReferenceDay() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

void main() {
  final referenceDay = _activeTripReferenceDay();

  final longArabicTrip = Trip.create(
    id: 'trip-ar-long',
    name: 'رحلة عمل إلى المملكة العربية السعودية للمؤتمر السنوي',
    destination: 'الرياض',
    baseCurrency: 'SAR',
    startDate: referenceDay.subtract(const Duration(days: 1)),
    endDate: referenceDay.add(const Duration(days: 4)),
    budget: 8000,
  );

  final sampleExpense = Expense.create(
    id: 'exp-ar',
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

  testWidgets('arabic trip list keeps currency in LTR widget', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(LtrText), findsWidgets);

    final currencyFinder = find.text('SAR');
    expect(currencyFinder, findsOneWidget);
    expect(
      tester.widget<Directionality>(
        find.ancestor(
          of: currencyFinder,
          matching: find.byType(Directionality),
        ).first,
      ).textDirection,
      TextDirection.ltr,
    );
  });

  testWidgets('arabic trip card survives long title without overflow',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('رحلة عمل'), findsOneWidget);
    expect(find.text('في سفر'), findsOneWidget);
  });

  testWidgets('arabic trip details keeps primary amount in LTR direction',
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
    expect(amountFinder, findsOneWidget);
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

  testWidgets('arabic trip details context strip uses LtrText for date range',
      (tester) async {
    final tripWithDates = longArabicTrip.copyWith(
      startDate: DateTime(2026, 5, 12),
      endDate: DateTime(2026, 5, 18),
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: tripWithDates,
        expenses: const [],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LtrText), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arabic quick add keeps amount LTR and readable action labels',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
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
    expect(find.text('إضافة تفاصيل'), findsOneWidget);

    final amountField = tester.widget<TextField>(find.byType(TextField).first);
    expect(amountField.textDirection, TextDirection.ltr);
  });

  testWidgets('arabic quick add payment chips stay on one row without overflow',
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
            expenses: const [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('نقداً'), findsOneWidget);
    expect(find.text('بطاقة'), findsOneWidget);
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

  @override
  Future<void> reload() async {
    state = AsyncData(_trips);
  }
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

class _EmptyCardRepository extends CardRepository {
  _EmptyCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async => const [];
}
