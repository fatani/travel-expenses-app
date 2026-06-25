import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/database/app_database.dart';
import 'package:travel_expenses/core/providers/database_providers.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_lot_repository.dart';
import 'package:travel_expenses/features/cash_wallet/data/cash_wallet_repository.dart';
import 'package:travel_expenses/features/cash_wallet/domain/trip_cash_balance.dart';
import 'package:travel_expenses/features/expenses/domain/expense.dart';
import 'package:travel_expenses/features/refunds/data/expense_refund_repository.dart';
import 'package:travel_expenses/features/refunds/domain/expense_refund.dart';
import 'package:travel_expenses/features/refunds/domain/record_refund_use_case.dart';
import 'package:travel_expenses/features/refunds/domain/refund_result.dart';
import 'package:travel_expenses/features/refunds/domain/refund_destination.dart';
import 'package:travel_expenses/features/refunds/domain/refund_inheritance_engine.dart';
import 'package:travel_expenses/features/refunds/presentation/refund_form_screen.dart';
import 'package:travel_expenses/features/refunds/presentation/trip_refund_form_screen.dart';
import 'package:travel_expenses/features/reports/data/trip_cash_balances_provider.dart';
import 'package:travel_expenses/features/reports/data/trip_report_provider.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_display.dart';
import 'package:travel_expenses/features/reports/domain/trip_report_summary.dart';
import 'package:travel_expenses/features/trips/domain/trip.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

void main() {
  final trip = Trip.create(
    id: 'trip-ax04',
    name: 'AX-04 Trip',
    destination: 'Test',
    baseCurrency: 'SAR',
    destinationCurrency: 'SAR',
    homeCurrencySnapshot: 'SAR',
  );

  final cardExpense = Expense.create(
    id: 'exp-card',
    tripId: trip.id,
    title: 'Card purchase',
    amount: 200,
    currencyCode: 'SAR',
    transactionAmount: 200,
    transactionCurrency: 'SAR',
    convertedHomeAmount: 200,
    homeCurrency: 'SAR',
    spentAt: DateTime.utc(2026, 6, 1),
    paymentMethod: 'Credit Card',
    paymentChannel: 'POS Purchase',
    category: 'Shopping',
  );

  TripReportDisplay minimalReport() {
    return TripReportDisplay(
      summary: TripReportSummary(
        tripId: trip.id,
        tripName: trip.name,
        totalExpenseCount: 1,
        internationalExpenseCount: 0,
        domesticExpenseCount: 1,
        totalBilledByCurrency: const [],
        totalFeesByCurrency: const [],
        topCategory: null,
        topPaymentNetwork: null,
        topPaymentChannel: null,
        byCategory: const [],
        byTransactionCurrency: const [],
        byPaymentNetwork: const [],
        byPaymentChannel: const [],
        smartInsights: const [],
        reportingMoneyPreviews: const [],
        remainingCashValues: const [],
        pendingCardExpenseCount: 0,
        cashAcquisitionSummary: const [],
        paymentSourceSummary: const [],
      ),
      refundsByTransactionCurrency: const [],
    );
  }

  group('AX-04 — refund provider invalidation parity', () {
    testWidgets('trip-level cash refund invalidates report and cash balances',
        (tester) async {
      final tracker = _ProviderFetchTracker();
      final container = ProviderContainer(
        overrides: [
          recordRefundUseCaseProvider.overrideWithValue(
            _StubRecordRefundUseCase(destination: RefundDestination.cash),
          ),
          tripReportProvider(trip.id).overrideWith((ref) async {
            tracker.reportFetches++;
            return minimalReport();
          }),
          tripCashBalancesProvider(trip.id).overrideWith((ref) async {
            tracker.cashBalanceFetches++;
            return [
              TripCashBalance(
                tripId: 'trip-ax04',
                currencyCode: 'SAR',
                balanceAmount: 100,
                updatedAt: DateTime.utc(2026, 6, 1),
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tripReportProvider(trip.id).future);
      await container.read(tripCashBalancesProvider(trip.id).future);
      expect(tracker.reportFetches, 1);
      expect(tracker.cashBalanceFetches, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: TripRefundFormScreen(trip: trip),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card refund'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash refund'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '50');
      await tester.tap(find.text('Record refund'));
      await tester.pumpAndSettle();

      await container.read(tripReportProvider(trip.id).future);
      await container.read(tripCashBalancesProvider(trip.id).future);
      expect(tracker.reportFetches, 2);
      expect(tracker.cashBalanceFetches, 2);
    });

    testWidgets('per-expense cash refund invalidates tripCashBalancesProvider',
        (tester) async {
      final tracker = _ProviderFetchTracker();
      final container = ProviderContainer(
        overrides: [
          recordRefundUseCaseProvider.overrideWithValue(
            _StubRecordRefundUseCase(destination: RefundDestination.cash),
          ),
          tripReportProvider(trip.id).overrideWith((ref) async {
            tracker.reportFetches++;
            return minimalReport();
          }),
          tripCashBalancesProvider(trip.id).overrideWith((ref) async {
            tracker.cashBalanceFetches++;
            return [
              TripCashBalance(
                tripId: 'trip-ax04',
                currencyCode: 'SAR',
                balanceAmount: 100,
                updatedAt: DateTime.utc(2026, 6, 1),
              ),
            ];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tripCashBalancesProvider(trip.id).future);
      expect(tracker.cashBalanceFetches, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RefundFormScreen(trip: trip, expense: cardExpense),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '25');
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      await container.read(tripCashBalancesProvider(trip.id).future);
      expect(tracker.cashBalanceFetches, 2);
    });

    testWidgets('card refund invalidates tripReportProvider', (tester) async {
      final tracker = _ProviderFetchTracker();
      final container = ProviderContainer(
        overrides: [
          recordRefundUseCaseProvider.overrideWithValue(
            _StubRecordRefundUseCase(destination: RefundDestination.card),
          ),
          tripReportProvider(trip.id).overrideWith((ref) async {
            tracker.reportFetches++;
            return minimalReport();
          }),
          tripCashBalancesProvider(trip.id).overrideWith((ref) async {
            tracker.cashBalanceFetches++;
            return const [];
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(tripReportProvider(trip.id).future);
      expect(tracker.reportFetches, 1);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: RefundFormScreen(trip: trip, expense: cardExpense),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '25');
      await tester.tap(find.widgetWithText(FilledButton, 'Record refund'));
      await tester.pumpAndSettle();

      await container.read(tripReportProvider(trip.id).future);
      expect(tracker.reportFetches, 2);
    });
  });
}

class _ProviderFetchTracker {
  int reportFetches = 0;
  int cashBalanceFetches = 0;
}

class _StubRecordRefundUseCase extends RecordRefundUseCase {
  _StubRecordRefundUseCase({required this.destination})
      : super(
          appDatabase: AppDatabase(),
          refundEngine: const RefundInheritanceEngine(),
          refundRepository: ExpenseRefundRepository(AppDatabase()),
          lotRepository: CashLotRepository(AppDatabase()),
          cashWalletRepository: CashWalletRepository(AppDatabase()),
        );

  final RefundDestination destination;

  @override
  Future<RefundResult> execute({
    required RefundDestination destination,
    required String tripId,
    String? expenseId,
    required double refundAmount,
    required String refundCurrency,
    double? homeAmount,
    String? homeCurrency,
    String? note,
    DateTime? createdAt,
    Expense? linkedExpense,
  }) async {
    return RefundResult(
      refund: ExpenseRefund.create(
        id: 'stub-refund',
        tripId: tripId,
        expenseId: expenseId,
        amount: refundAmount,
        currencyCode: refundCurrency,
        homeAmount: homeAmount,
        homeCurrency: homeCurrency,
        destination: this.destination,
      ),
    );
  }
}
