import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/formatting/bidi_format.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/core/theme/rtl_typography.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/cash_transaction.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
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
    id: 'trip-final-ar',
    name: 'رحلة عمل إلى المملكة العربية السعودية للمؤتمر السنوي',
    destination: 'الرياض',
    baseCurrency: 'SAR',
    startDate: now.subtract(const Duration(days: 1)),
    endDate: now.add(const Duration(days: 4)),
    budget: 8000,
  );

  final multiCurrencyExpenses = [
    Expense.create(
      id: 'exp-usd',
      tripId: longArabicTrip.id,
      title: 'فندق',
      amount: 100,
      currencyCode: 'USD',
      transactionAmount: 100,
      transactionCurrency: 'USD',
      spentAt: DateTime(2026, 5, 24),
      paymentMethod: 'Cash',
      category: 'Accommodation',
    ),
    Expense.create(
      id: 'exp-eur',
      tripId: longArabicTrip.id,
      title: 'تاكسي',
      amount: 40,
      currencyCode: 'EUR',
      transactionAmount: 40,
      transactionCurrency: 'EUR',
      spentAt: DateTime(2026, 5, 24, 18),
      paymentMethod: 'Cash',
      category: 'Transport',
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': true,
    });
  });

  test('export presentation has no hardcoded Arabic user strings', () {
    final exportDir = Directory('lib/features/export/presentation');
    expect(exportDir.existsSync(), isTrue);

    final hardcodedArabic = RegExp(r'''['"][^'"]*[\u0600-\u06FF]''');
    for (final file in exportDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final content = file.readAsStringSync();
      expect(
        hardcodedArabic.hasMatch(content),
        isFalse,
        reason: 'Hardcoded Arabic found in ${file.path}',
      );
    }
  });

  testWidgets('english core surfaces avoid smart AI and marketing tone',
      (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Smart'), findsNothing);
    expect(find.textContaining('AI '), findsNothing);
    expect(find.textContaining('insights'), findsNothing);
    expect(find.textContaining('successfully'), findsNothing);
    expect(find.textContaining('Great'), findsNothing);
  });

  testWidgets('arabic trip list has no overflow at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('في سفر'), findsOneWidget);
  });

  testWidgets('arabic trip details has no overflow at 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: longArabicTrip,
        expenses: multiCurrencyExpenses,
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Mixed'), findsNothing);
    expect(find.textContaining('150 '), findsNothing);
  });

  testWidgets('arabic quick add keeps save reachable at 360x640', (tester) async {
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
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'نقداً'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'بطاقة'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'أخرى'), findsOneWidget);
    expect(find.text('Apple Pay'), findsNothing);
  });

  testWidgets('arabic expense form prefill from quick add stays stable',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: longArabicTrip,
        expenses: const [],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField).first,
    );
    await tester.enterText(amountField, '45');
    await tester.ensureVisible(find.text('إضافة تفاصيل'));
    await tester.tap(find.text('إضافة تفاصيل'));
    await tester.pumpAndSettle();

    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    final formAmountField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(formAmountField.controller?.text, '45');
  });

  testWidgets('arabic trip details amounts stay LTR-safe', (tester) async {
    final expense = Expense.create(
      id: 'exp-ltr',
      tripId: longArabicTrip.id,
      title: 'مقهى',
      amount: 320,
      currencyCode: 'SAR',
      transactionAmount: 320,
      transactionCurrency: 'SAR',
      spentAt: DateTime(2026, 5, 24, 14, 30),
      paymentMethod: 'Cash',
      category: 'Food',
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: longArabicTrip,
        expenses: [expense],
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

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
    expect(find.byType(LtrText), findsWidgets);
  });

  testWidgets('delete expense dialog keeps calm short copy', (tester) async {
    final expense = Expense.create(
      id: 'exp-del',
      tripId: longArabicTrip.id,
      title: 'Coffee',
      amount: 12,
      currencyCode: 'SAR',
      transactionAmount: 12,
      transactionCurrency: 'SAR',
      spentAt: DateTime(2026, 5, 16),
      paymentMethod: 'Cash',
      category: 'Food',
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: longArabicTrip,
        expenses: [expense],
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete expense?'), findsOneWidget);
    expect(find.textContaining('successfully'), findsNothing);
    expect(find.textContaining('Great'), findsNothing);
  });

  testWidgets('arabic delete trip dialog uses calm title weight', (tester) async {
    await tester.pumpWidget(
      _buildTripsListApp(trips: [longArabicTrip], locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف الرحلة'));
    await tester.pumpAndSettle();

    final titleFinder = find.text('حذف الرحلة؟');
    expect(titleFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleFinder);
    expect(titleText.style?.fontWeight, RtlTypography.titleWeight(true));
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
