import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_provider.dart';
import 'package:travel_expenses/features/global_reports/domain/global_report_summary.dart';
import 'package:travel_expenses/features/global_reports/presentation/global_reports_screen.dart';
import 'package:travel_expenses/features/settings/data/card_repository.dart';
import 'package:travel_expenses/features/settings/domain/app_settings.dart';
import 'package:travel_expenses/features/settings/domain/card_profile.dart';
import 'package:travel_expenses/features/settings/presentation/settings_controller.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/features/trips/presentation/trip_controller.dart';
import 'package:travel_expenses/features/trips/presentation/trips_list_screen.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-calm-snackbar',
    name: 'Test Trip',
    destination: 'Test',
    baseCurrency: 'CNY',
    destinationCurrency: 'CNY',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('quick save shows one undo snackbar without cash guidance',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenseRepository: _FakeExpenseRepository(),
        cashWalletRepository: _InsufficientCashWalletRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await _quickSave(tester);

    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('No cash added yet'), findsNothing);
    expect(find.text('Cash balance may need adjustment'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('card quick save does not show cash guidance snackbar',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenseRepository: _FakeExpenseRepository(),
        cashWalletRepository: _InsufficientCashWalletRepository(),
        cardRepository: _SingleCardRepository(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    final amountField = find.descendant(
      of: find.byType(QuickAddExpenseSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(amountField, '40');
    await tester.tap(find.text('Visa ****1234'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Quick Save'));
    await tester.tap(find.text('Quick Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('No cash added yet'), findsNothing);
    expect(find.text('Add Cash'), findsNothing);
  });

  testWidgets('delete confirmation dialog still appears from expense card',
      (tester) async {
    final expense = Expense.create(
      id: 'expense-delete',
      tripId: trip.id,
      title: 'Coffee',
      amount: 12,
      currencyCode: 'CNY',
      transactionAmount: 12,
      transactionCurrency: 'CNY',
      spentAt: DateTime(2026, 5, 16),
      paymentMethod: 'Cash',
      paymentChannel: 'Cash',
      category: 'Food',
    );

    await tester.pumpWidget(
      _buildTripDetailsApp(
        trip: trip,
        expenseRepository: _FakeExpenseRepository(initialExpenses: [expense]),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete expense?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('trips empty state has one CTA and no illustration',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'trips_has_ever_had_at_least_one_trip': false,
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripsControllerProvider.overrideWith(() => _FakeTripsController(const [])),
          settingsControllerProvider.overrideWith(_FakeSettingsController.new),
          cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TripsListScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add trip'), findsOneWidget);
    expect(find.text('Global reports'), findsNothing);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('global reports empty state has one CTA and no marketing subtitle',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalReportProvider.overrideWith(
            (ref) async => _emptyGlobalReportSummary,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const GlobalReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No trips yet'), findsOneWidget);
    expect(find.text('Add Trip'), findsOneWidget);
    expect(
      find.text('Add your first trip to start tracking expenses and see global reports.'),
      findsNothing,
    );
  });
}

Future<void> _quickSave(WidgetTester tester) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  final amountField = find.descendant(
    of: find.byType(QuickAddExpenseSheet),
    matching: find.byType(TextField),
  );
  await tester.enterText(amountField, '25');
  await tester.tap(find.text('Cash'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Quick Save'));
  await tester.tap(find.text('Quick Save'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

const _emptyGlobalReportSummary = GlobalReportSummary(
  totalTrips: 0,
  activeTrips: 0,
  totalExpenseCount: 0,
  internationalExpenseCount: 0,
  domesticExpenseCount: 0,
  trackedTripDays: 0,
  totalBilledByCurrency: [],
  averageSpendPerTripByCurrency: [],
  averageDailySpendByCurrency: [],
  topCategory: null,
  mostUsedPaymentChannel: null,
  mostUsedPaymentNetwork: null,
  dominantCurrency: null,
  dominantCategory: null,
  uniqueCategoryCount: 0,
  uniquePaymentChannelCount: 0,
  uniquePaymentNetworkCount: 0,
  uniqueTransactionCurrencyCount: 0,
  smartInsights: [],
  behavioralInsights: [],
);

Widget _buildTripDetailsApp({
  required Trip trip,
  required ExpenseRepository expenseRepository,
  CashWalletRepository? cashWalletRepository,
  CardRepository? cardRepository,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(expenseRepository),
      cashWalletRepositoryProvider.overrideWithValue(
        cashWalletRepository ?? _EmptyCashWalletRepository(),
      ),
      if (cardRepository != null)
        cardRepositoryProvider.overrideWithValue(cardRepository),
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
  Future<Expense> createExpense(Expense expense) async {
    _expenses.add(expense);
    return expense;
  }

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }
}

class _InsufficientCashWalletRepository extends CashWalletRepository {
  _InsufficientCashWalletRepository() : super(AppDatabase());

  @override
  Future<CashExpenseDeductionResult> recordCashExpenseDeduction({
    required String tripId,
    String? expenseId,
    required double amount,
    required String currencyCode,
    String? note,
  }) async {
    return CashExpenseDeductionResult(
      wasInsufficientBeforeDeduction: true,
      balanceAfterDeduction: -amount,
    );
  }
}

class _EmptyCashWalletRepository extends CashWalletRepository {
  _EmptyCashWalletRepository() : super(AppDatabase());
}

class _SingleCardRepository extends CardRepository {
  _SingleCardRepository() : super(AppDatabase());

  @override
  Future<List<CardProfile>> getAllCards() async {
    final now = DateTime(2026, 5, 25);
    return [
      CardProfile(
        id: 1,
        name: 'Visa',
        cardNetwork: 'Visa',
        last4: '1234',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
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
