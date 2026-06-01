import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/global_reports/data/global_report_provider.dart';
import 'package:travel_expenses/features/global_reports/domain/global_report_summary.dart';
import 'package:travel_expenses/features/global_reports/presentation/global_reports_screen.dart';
import 'package:travel_expenses/features/insights/domain/insight.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

GlobalReportSummary _summaryWithTripsNoExpenses({int totalTrips = 2}) {
  return GlobalReportSummary(
    totalTrips: totalTrips,
    activeTrips: 0,
    totalExpenseCount: 0,
    internationalExpenseCount: 0,
    domesticExpenseCount: 0,
    trackedTripDays: 4,
    totalBilledByCurrency: const [],
    averageSpendPerTripByCurrency: const [],
    averageDailySpendByCurrency: const [],
    mostUsedPaymentChannel: null,
    mostUsedPaymentNetwork: null,
    dominantCurrency: null,
    dominantCategory: null,
    uniqueCategoryCount: 0,
    uniquePaymentChannelCount: 0,
    uniquePaymentNetworkCount: 0,
    uniqueTransactionCurrencyCount: 0,
    smartInsights: const [],
    behavioralInsights: const [],
  );
}

GlobalReportSummary _summaryWithExpenses() {
  return GlobalReportSummary(
    totalTrips: 2,
    activeTrips: 2,
    totalExpenseCount: 4,
    internationalExpenseCount: 1,
    domesticExpenseCount: 3,
    trackedTripDays: 8,
    totalBilledByCurrency: const [],
    averageSpendPerTripByCurrency: const [],
    averageDailySpendByCurrency: const [],
    mostUsedPaymentChannel: 'POS Purchase',
    mostUsedPaymentNetwork: 'Visa',
    dominantCurrency: 'SAR',
    dominantCategory: 'Food',
    uniqueCategoryCount: 2,
    uniquePaymentChannelCount: 2,
    uniquePaymentNetworkCount: 1,
    uniqueTransactionCurrencyCount: 1,
    smartInsights: const [
      GlobalReportInsight(type: GlobalReportInsightType.categoryVariation),
    ],
    behavioralInsights: const [
      Insight(type: InsightType.spike, percentage: 42),
    ],
  );
}

Widget _buildApp(GlobalReportSummary summary) {
  return ProviderScope(
    overrides: [
      globalReportProvider.overrideWith((ref) async => summary),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const GlobalReportsScreen(),
    ),
  );
}

void main() {
  testWidgets('shows guidance when trips exist but there are no expenses', (tester) async {
    await tester.pumpWidget(_buildApp(_summaryWithTripsNoExpenses()));
    await tester.pumpAndSettle();

    expect(find.text('Add expenses to see your global report.'), findsOneWidget);
    expect(find.text('Total trips'), findsOneWidget);
    expect(find.text('Overview'), findsNothing);
    expect(find.text('Summary'), findsNothing);
  });

  testWidgets('renders report sections when expenses exist', (tester) async {
    await tester.pumpWidget(_buildApp(_summaryWithExpenses()));
    await tester.pumpAndSettle();

    expect(find.text('Add expenses to see your global report.'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });

  test('InsightType has no dead fees variant', () {
    expect(InsightType.values, [InsightType.spike, InsightType.categoryDrift]);
  });

  test('GlobalReportInsightType exposes only live smart insight variants', () {
    expect(
      GlobalReportInsightType.values,
      [
        GlobalReportInsightType.currencyDistribution,
        GlobalReportInsightType.categoryVariation,
        GlobalReportInsightType.paymentVariation,
      ],
    );
  });
}
