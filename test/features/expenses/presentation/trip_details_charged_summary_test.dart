import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/test_expense_repository.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/expenses/presentation/trip_details_screen.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-charged-summary',
    name: 'Dubai',
    destination: 'Dubai',
    baseCurrency: 'AED',
  );

  testWidgets('card charge summaries are not shown as dashboard stats',
      (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'intl-sar-1',
          tripId: trip.id,
          title: 'Hotel',
          amount: 100,
          currencyCode: 'USD',
          transactionAmount: 100,
          transactionCurrency: 'USD',
          totalChargedAmount: 100,
          totalChargedCurrency: 'SAR',
          isInternational: true,
          spentAt: DateTime(2026, 4, 13),
          paymentMethod: 'Credit Card',
          category: 'Accommodation',
        ),
        Expense.create(
          id: 'intl-sar-2',
          tripId: trip.id,
          title: 'Taxi',
          amount: 20,
          currencyCode: 'USD',
          transactionAmount: 20,
          transactionCurrency: 'USD',
          totalChargedAmount: 50,
          totalChargedCurrency: 'SAR',
          isInternational: true,
          spentAt: DateTime(2026, 4, 14),
          paymentMethod: 'Credit Card',
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

    expect(find.text('Card charges in SAR'), findsNothing);
    expect(find.textContaining('150 SAR'), findsNothing);
    expect(find.text('Card charges in multiple currencies'), findsNothing);
    expect(find.text('Mixed'), findsNothing);
    expect(find.text('Hotel'), findsOneWidget);
  });

  testWidgets('Arabic locale also hides card charge dashboard stats', (tester) async {
    final repository = _FakeExpenseRepository(
      initialExpenses: [
        Expense.create(
          id: 'intl-sar',
          tripId: trip.id,
          title: 'Hotel',
          amount: 100,
          currencyCode: 'USD',
          transactionAmount: 100,
          transactionCurrency: 'USD',
          totalChargedAmount: 100,
          totalChargedCurrency: 'SAR',
          isInternational: true,
          spentAt: DateTime(2026, 4, 13),
          paymentMethod: 'Credit Card',
          category: 'Accommodation',
        ),
        Expense.create(
          id: 'intl-aed',
          tripId: trip.id,
          title: 'Local fee',
          amount: 50,
          currencyCode: 'EUR',
          transactionAmount: 50,
          transactionCurrency: 'EUR',
          totalChargedAmount: 50,
          totalChargedCurrency: 'AED',
          isInternational: true,
          spentAt: DateTime(2026, 4, 14),
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

    expect(find.text('مشتريات البطاقة بعدة عملات'), findsNothing);
    expect(find.text('مختلطة'), findsNothing);
    expect(find.text('مشتريات البطاقة بعملة SAR'), findsNothing);
  });
}

Widget _buildApp({
  required Widget child,
  List<Override> overrides = const [],
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      cashWalletRepositoryProvider.overrideWithValue(_EmptyCashWalletRepository()),
      ...overrides,
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
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
}
