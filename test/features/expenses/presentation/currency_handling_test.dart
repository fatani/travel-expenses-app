import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/expenses/data/expense_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/expense_form_screen.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/sms_parser/presentation/sms_expense_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-1',
    name: 'Shanghai',
    destination: 'Shanghai',
    baseCurrency: 'CNY',
  );

  testWidgets(
    'trip details total excludes expenses with other currencies and shows warning',
    (tester) async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'e1',
            tripId: trip.id,
            title: 'Lunch',
            amount: 10,
            currencyCode: 'CNY',
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
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Cash',
            category: 'Transport',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(
          child: TripDetailsScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CNY 10.00'), findsOneWidget);
      expect(find.text('CNY 30.00'), findsNothing);
      expect(
        find.text(
          'Some expenses in other currencies are not included in the total',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'domestic SAR trip totals only SAR transaction amounts',
    (tester) async {
      final domesticTrip = Trip.create(
        id: 'trip-sar',
        name: 'Riyadh',
        destination: 'Riyadh',
        baseCurrency: 'SAR',
      );

      final repository = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'sar-1',
            tripId: domesticTrip.id,
            title: 'Lunch',
            amount: 50,
            currencyCode: 'SAR',
            transactionAmount: 50,
            transactionCurrency: 'SAR',
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Cash',
            category: 'Food',
          ),
          Expense.create(
            id: 'usd-1',
            tripId: domesticTrip.id,
            title: 'Online service',
            amount: 20,
            currencyCode: 'USD',
            transactionAmount: 20,
            transactionCurrency: 'USD',
            feesAmount: 1,
            feesCurrency: 'SAR',
            isInternational: true,
            spentAt: DateTime(2026, 4, 12),
            paymentMethod: 'Credit Card',
            category: 'Other',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(
          child: TripDetailsScreen(trip: domesticTrip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('SAR 50.00'), findsOneWidget);
      expect(find.text('SAR 70.00'), findsNothing);
      expect(
        find.text(
          'Some expenses in other currencies are not included in the total',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'trip details shows no-base-currency message instead of misleading zero and keeps SAR charged total',
    (tester) async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'intl-1',
            tripId: trip.id,
            title: 'Bangkok ride',
            amount: 10,
            currencyCode: 'THB',
            transactionAmount: 10,
            transactionCurrency: 'THB',
            billedAmount: 1.18,
            billedCurrency: 'SAR',
            feesAmount: 0.02,
            feesCurrency: 'SAR',
            totalChargedAmount: 1.20,
            totalChargedCurrency: 'SAR',
            isInternational: true,
            spentAt: DateTime(2026, 4, 13),
            paymentMethod: 'Credit Card',
            category: 'Transport',
          ),
          Expense.create(
            id: 'intl-2',
            tripId: trip.id,
            title: 'Online tool',
            amount: 3,
            currencyCode: 'USD',
            transactionAmount: 3,
            transactionCurrency: 'USD',
            billedAmount: 11.25,
            billedCurrency: 'SAR',
            isInternational: true,
            spentAt: DateTime(2026, 4, 13),
            paymentMethod: 'Credit Card',
            category: 'Other',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(
          child: TripDetailsScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No expenses in this currency'), findsOneWidget);
      expect(find.text('CNY 0.00'), findsNothing);
      expect(find.text('Total charged (SAR)'), findsOneWidget);
      expect(find.text('SAR 12.45'), findsOneWidget);
    },
  );

  testWidgets(
    'trip details shows Arabic no-base-currency message and charged total label in ar locale',
    (tester) async {
      final repository = _FakeExpenseRepository(
        initialExpenses: [
          Expense.create(
            id: 'intl-ar-1',
            tripId: trip.id,
            title: 'Bangkok ride',
            amount: 10,
            currencyCode: 'THB',
            transactionAmount: 10,
            transactionCurrency: 'THB',
            billedAmount: 1.18,
            billedCurrency: 'SAR',
            feesAmount: 0.02,
            feesCurrency: 'SAR',
            totalChargedAmount: 1.20,
            totalChargedCurrency: 'SAR',
            isInternational: true,
            spentAt: DateTime(2026, 4, 13),
            paymentMethod: 'Credit Card',
            category: 'Transport',
          ),
          Expense.create(
            id: 'intl-ar-2',
            tripId: trip.id,
            title: 'Online tool',
            amount: 3,
            currencyCode: 'USD',
            transactionAmount: 3,
            transactionCurrency: 'USD',
            billedAmount: 11.25,
            billedCurrency: 'SAR',
            isInternational: true,
            spentAt: DateTime(2026, 4, 13),
            paymentMethod: 'Credit Card',
            category: 'Other',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildApp(
          child: TripDetailsScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
          locale: const Locale('ar'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('لا توجد مصاريف بهذه العملة'), findsOneWidget);
      expect(find.text('CNY 0.00'), findsNothing);
      expect(find.text('إجمالي المخصوم'), findsOneWidget);
      expect(find.text('SAR 12.45'), findsOneWidget);
    },
  );

  testWidgets(
    'empty trip details state keeps trip summary fixed and does not scroll',
    (tester) async {
      final repository = _FakeExpenseRepository(initialExpenses: const []);

      await tester.pumpWidget(
        _buildApp(
          child: TripDetailsScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final titleFinder = find.text(trip.name).first;
      final emptyStateFinder = find.text('No expenses yet');
      final initialPosition = tester.getTopLeft(titleFinder);

      expect(emptyStateFinder, findsOneWidget);

      await tester.drag(find.byType(Scaffold), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(titleFinder), equals(initialPosition));
    },
  );

  testWidgets(
    'manual expense creation asks for confirmation when currency differs',
    (tester) async {
      final repository = _FakeExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: ExpenseFormScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Coffee');
      await tester.enterText(find.byType(TextFormField).at(1), '12.50');
      await tester.enterText(find.byType(TextFormField).at(2), 'SAR');

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visa').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS Purchase').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextFormField).at(3));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextFormField).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Expense'));
      await tester.tap(find.text('Create Expense'));
      await tester.pumpAndSettle();

      expect(
        find.text('Currency differs from trip base currency'),
        findsOneWidget,
      );
      expect(repository.createdExpenses, isEmpty);

      await tester.tap(find.text('Convert manually'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, isEmpty);

      await tester.ensureVisible(find.text('Create Expense'));
      await tester.tap(find.text('Create Expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep as-is'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      expect(repository.createdExpenses.single.currencyCode, 'SAR');
    },
  );

  testWidgets(
    'manual expense form shows asterisks for required fields before validation',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: ExpenseFormScreen(trip: trip),
          overrides: const [],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Currency *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Card network *'), findsOneWidget);
      expect(find.text('Payment channel *'), findsOneWidget);
      expect(find.text('Expense date *'), findsOneWidget);
      expect(find.text('Expense time *'), findsOneWidget);
      expect(find.text('This field is required.'), findsNothing);
    },
  );

  testWidgets(
    'sms expense creation asks for confirmation when currency differs',
    (tester) async {
      final repository = _FakeExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Bank sms text');
      await tester.enterText(find.byType(TextFormField).at(1), 'Mobily');
      await tester.enterText(find.byType(TextFormField).at(2), '46.00');
      await tester.enterText(find.byType(TextFormField).at(3), 'SAR');

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Visa').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online Purchase').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextFormField).at(4));
      await tester.tap(find.byType(TextFormField).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextFormField).at(5));
      await tester.tap(find.byType(TextFormField).at(5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(
        find.text('Currency differs from trip base currency'),
        findsOneWidget,
      );
      expect(repository.createdExpenses, isEmpty);

      await tester.tap(find.text('Keep as-is'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      expect(repository.createdExpenses.single.currencyCode, 'SAR');
      expect(repository.createdExpenses.single.source, 'sms');
      expect(repository.createdExpenses.single.paymentNetwork, 'Visa');
      expect(repository.createdExpenses.single.paymentChannel, 'Online Purchase');
      expect(repository.createdExpenses.single.paymentMethod, 'Credit Card');
    },
  );

  testWidgets(
    'sms expense creation does not show currency warning when billed currency matches trip base and currency was parser-filled',
    (tester) async {
      final sarTrip = Trip.create(
        id: 'trip-sar-d360',
        name: 'Riyadh',
        destination: 'Riyadh',
        baseCurrency: 'SAR',
      );
      final repository = _FakeExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: sarTrip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '''
بطاقة: 8263 VISA Ecommerce
مبلغ: THB 10.00 (SAR 1.18)
لدى: AMP*AIS SERVICES
في: 08:01 2026-04-16
''',
      );

      await tester.tap(find.text('Parse SMS'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(find.text('Currency differs from trip base currency'), findsNothing);
      expect(repository.createdExpenses, hasLength(1));
      expect(repository.createdExpenses.single.currencyCode, 'THB');
      expect(repository.createdExpenses.single.billedCurrency, 'SAR');
    },
  );

  testWidgets(
    'sms form shows asterisks for required fields before validation',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: trip),
          overrides: const [],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bank SMS text *'), findsOneWidget);
      expect(find.text('Amount *'), findsOneWidget);
      expect(find.text('Currency *'), findsOneWidget);
      expect(find.text('Category *'), findsOneWidget);
      expect(find.text('Card network *'), findsOneWidget);
      expect(find.text('Payment channel *'), findsOneWidget);
      expect(find.text('Expense date *'), findsOneWidget);
      expect(find.text('This field is required.'), findsNothing);
    },
  );

  testWidgets(
    'sms date editing preserves parsed time and saves updated day',
    (tester) async {
      final repository = _FakeExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '''
شراء عبر نقاط البيع
بطاقة:8664 ;فيزا-ابل باي
لدى:NAFTHAT A
مبلغ:15 SAR
رصيد:1780.92 SAR
12/4/26 13:24
''',
      );

      await tester.tap(find.text('Parse SMS'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextFormField).at(4));
      await tester.tap(find.byType(TextFormField).at(4));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      expect(repository.createdExpenses.single.spentAt, DateTime(2026, 4, 20, 13, 24));
      expect(repository.createdExpenses.single.paymentNetwork, 'Visa');
      expect(repository.createdExpenses.single.paymentChannel, 'POS Purchase');
    },
  );

  testWidgets(
    'sms parse of SAB international purchase keeps dropdown-safe payment channel',
    (tester) async {
      final repository = _FakeExpenseRepository();

      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: trip),
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '''
PoS International Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at www.shein.com for SAR 909.97 in UNITED ARAB EMIRATES
Exchange rate: 1.00000
Amount in SAR: 909.97
International Fees: 20.92
Total amount: 930.89
Date: 2026-02-22 14:34:20
Balance: SAR 2354.38
''',
      );

      await tester.tap(find.text('Parse SMS'));
      await tester.pumpAndSettle();

      final channelState = tester.state<FormFieldState<String>>(
        find.byType(DropdownButtonFormField<String>).at(2),
      );
      expect(channelState.value, 'POS Purchase');

      await tester.ensureVisible(find.text('Save Expense'));
      await tester.tap(find.text('Save Expense'));
      await tester.pumpAndSettle();

      expect(repository.createdExpenses, hasLength(1));
      expect(repository.createdExpenses.single.amount, 909.97);
      expect(repository.createdExpenses.single.currencyCode, 'SAR');
      expect(repository.createdExpenses.single.title, 'www.shein.com');
      expect(repository.createdExpenses.single.paymentNetwork, 'Mastercard');
      expect(repository.createdExpenses.single.paymentChannel, 'POS Purchase');
    },
  );

  testWidgets(
    'sms parse shows billed, fees, and total charged breakdown for SAB THB message',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(
          child: SmsExpenseScreen(trip: trip),
          overrides: const [],
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        '''
Online Purchase
SAB Mastercard Alfursan Credit Card (8263) was used at AMP*AIS SERVICES for THB 10.00 in THAILAND
Exchange rate: 0.11800
Amount in SAR: 1.18
International Fees in SAR: 0.02
Total amount in SAR: 1.20
Date: 2026-04-10 11:42:33
Balance: SAR 1141.56
''',
      );

      await tester.tap(find.text('Parse SMS'));
      await tester.pumpAndSettle();

      expect(find.text('International breakdown'), findsOneWidget);
      // Labels and values are now separate Text widgets in a Row.
      expect(find.text('Billed'), findsOneWidget);
      expect(find.text('SAR 1.18'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('SAR 0.02'), findsOneWidget);
      expect(find.text('Total charged'), findsOneWidget);
      expect(find.text('SAR 1.20'), findsOneWidget);

      // Main transaction fields remain primary.
      expect(find.text('10.00'), findsWidgets);
      expect(find.text('THB'), findsWidgets);
    },
  );
}

Widget _buildApp({
  required Widget child,
  required List<Override> overrides,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

class _FakeExpenseRepository extends ExpenseRepository {
  _FakeExpenseRepository({List<Expense>? initialExpenses})
      : _expenses = List<Expense>.from(initialExpenses ?? const <Expense>[]),
        super(AppDatabase());

  final List<Expense> _expenses;
  final List<Expense> createdExpenses = <Expense>[];

  @override
  Future<Expense> createExpense(Expense expense) async {
    createdExpenses.add(expense);
    _expenses.add(expense);
    return expense;
  }

  @override
  Future<List<Expense>> getExpensesByTrip(String tripId) async {
    return _expenses.where((expense) => expense.tripId == tripId).toList();
  }

  @override
  Future<Expense> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((item) => item.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
    }
    return expense;
  }

  @override
  Future<void> deleteExpense(String id) async {
    _expenses.removeWhere((expense) => expense.id == id);
  }
}