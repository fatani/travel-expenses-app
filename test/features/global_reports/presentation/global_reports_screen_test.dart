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
    averageSpendPerTripByCurrency: const [
      GlobalCurrencyMetric(currency: 'SAR', amount: 500),
    ],
    averageDailySpendByCurrency: const [
      GlobalCurrencyMetric(currency: 'SAR', amount: 125),
    ],
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

GlobalReportSummary _summaryWithExpenses({
  int totalTrips = 2,
  List<GlobalCurrencyMetric> averageSpendPerTripByCurrency = const [],
  List<GlobalCurrencyMetric> averageDailySpendByCurrency = const [],
}) {
  return GlobalReportSummary(
    totalTrips: totalTrips,
    activeTrips: 2,
    totalExpenseCount: 4,
    internationalExpenseCount: 1,
    domesticExpenseCount: 3,
    trackedTripDays: 8,
    totalBilledByCurrency: const [],
    averageSpendPerTripByCurrency: averageSpendPerTripByCurrency,
    averageDailySpendByCurrency: averageDailySpendByCurrency,
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

Widget _buildApp(
  GlobalReportSummary summary, {
  Locale? locale,
}) {
  return ProviderScope(
    overrides: [
      globalReportProvider.overrideWith((ref) async => summary),
    ],
    child: MaterialApp(
      locale: locale,
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
    expect(find.text('Average spending per trip'), findsNothing);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('renders report sections when expenses exist', (tester) async {
    await tester.pumpWidget(_buildApp(_summaryWithExpenses()));
    await tester.pumpAndSettle();

    expect(find.text('Add expenses to see your global report.'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
  });

  testWidgets('hides average spend per trip with one trip', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          totalTrips: 1,
          averageSpendPerTripByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 1240),
          ],
          averageDailySpendByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 310),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Average spending per trip'), findsNothing);
    expect(find.text('1240 SAR'), findsNothing);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('hides average spend per trip when metrics list is empty', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          averageSpendPerTripByCurrency: const [],
          averageDailySpendByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 50),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Average spending per trip'), findsNothing);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('renders average spend per trip with two or more trips and expenses',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          averageSpendPerTripByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 1240),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Average spending per trip'), findsOneWidget);
    expect(find.text('1240 SAR'), findsOneWidget);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('renders multiple currencies as separate average rows', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          averageSpendPerTripByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 1240),
            GlobalCurrencyMetric(currency: 'USD', amount: 310),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1240 SAR'), findsOneWidget);
    expect(find.text('310 USD'), findsOneWidget);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('does not render average daily spend even when present in summary',
      (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          averageSpendPerTripByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 800),
          ],
          averageDailySpendByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 200),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('800 SAR'), findsOneWidget);
    expect(find.text('200 SAR'), findsNothing);
    expect(find.text('Average daily spending'), findsNothing);
  });

  testWidgets('renders Arabic average spend per trip label', (tester) async {
    await tester.pumpWidget(
      _buildApp(
        _summaryWithExpenses(
          averageSpendPerTripByCurrency: const [
            GlobalCurrencyMetric(currency: 'SAR', amount: 1240),
          ],
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('متوسط الصرف لكل رحلة'), findsOneWidget);
    expect(find.text('1240 SAR'), findsOneWidget);
    expect(find.text('متوسط الصرف اليومي'), findsNothing);
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
