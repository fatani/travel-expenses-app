import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/predictions/domain/trip_prediction_summary.dart';
import 'package:travel_expenses/features/predictions/presentation/trip_prediction_section.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

TripPredictionSummary _summary({required bool hasBudgetWarning}) {
  return TripPredictionSummary(
    elapsedDays: 5,
    remainingDays: 4,
    burnRateByCurrency: const {'SAR': 100},
    forecastTotalByCurrency: const {'SAR': 500},
    hasBudgetWarning: hasBudgetWarning,
  );
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required TripPredictionSummary summary,
  required Locale locale,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TripPredictionSection(
          summary: summary,
          title: 'Predictions',
          burnRateTitle: 'Burn rate',
          forecastTitle: 'Forecast',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows remaining days in forecast section', (tester) async {
    await _pumpSection(
      tester,
      summary: _summary(hasBudgetWarning: false),
      locale: const Locale('en'),
    );

    expect(find.text('Remaining days: 4'), findsOneWidget);
  });

  testWidgets('shows localized budget warning in English', (tester) async {
    await _pumpSection(
      tester,
      summary: _summary(hasBudgetWarning: true),
      locale: const Locale('en'),
    );

    expect(
      find.textContaining('You are expected to exceed your current budget'),
      findsOneWidget,
    );
    expect(find.textContaining('ميزانيتك'), findsNothing);
  });

  testWidgets('shows localized budget warning in Arabic', (tester) async {
    await _pumpSection(
      tester,
      summary: _summary(hasBudgetWarning: true),
      locale: const Locale('ar'),
    );

    expect(
      find.textContaining('من المتوقع أن تتجاوز ميزانيتك الحالية'),
      findsOneWidget,
    );
    expect(
      find.textContaining('You are expected to exceed your current budget'),
      findsNothing,
    );
  });

  testWidgets('hides budget warning when not flagged', (tester) async {
    await _pumpSection(
      tester,
      summary: _summary(hasBudgetWarning: false),
      locale: const Locale('en'),
    );

    expect(
      find.textContaining('You are expected to exceed your current budget'),
      findsNothing,
    );
  });
}
