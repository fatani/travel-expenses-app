import '../../reports/domain/report_bucket.dart';

class GlobalCurrencyMetric {
  const GlobalCurrencyMetric({
    required this.currency,
    required this.amount,
  });

  final String currency;
  final double amount;
}

enum GlobalReportInsightType {
  dominantPaymentChannel,
  dominantCategory,
  averageSpendPerTrip,
  dominantCurrency,
  currencyDistribution,
  internationalDomesticRatio,
}

class GlobalReportInsight {
  const GlobalReportInsight({
    required this.type,
    this.subject,
    this.percentage,
    this.amount,
    this.currency,
  });

  final GlobalReportInsightType type;
  final String? subject;
  final int? percentage;
  final double? amount;
  final String? currency;
}

class GlobalReportSummary {
  const GlobalReportSummary({
    required this.totalTrips,
    required this.activeTrips,
    required this.totalExpenseCount,
    required this.internationalExpenseCount,
    required this.domesticExpenseCount,
    required this.trackedTripDays,
    required this.totalBilledByCurrency,
    required this.averageSpendPerTripByCurrency,
    required this.averageDailySpendByCurrency,
    required this.topCategory,
    required this.mostUsedPaymentChannel,
    required this.mostUsedPaymentNetwork,
    required this.dominantCurrency,
    required this.dominantCategory,
    required this.smartInsights,
  });

  final int totalTrips;
  final int activeTrips;
  final int totalExpenseCount;
  final int internationalExpenseCount;
  final int domesticExpenseCount;
  final int trackedTripDays;
  final List<ReportBucket> totalBilledByCurrency;
  final List<GlobalCurrencyMetric> averageSpendPerTripByCurrency;
  final List<GlobalCurrencyMetric> averageDailySpendByCurrency;
  final String? topCategory;
  final String? mostUsedPaymentChannel;
  final String? mostUsedPaymentNetwork;
  final String? dominantCurrency;
  final String? dominantCategory;
  final List<GlobalReportInsight> smartInsights;

  bool get hasTrips => totalTrips > 0;
  bool get hasExpenses => totalExpenseCount > 0;

  int get internationalRatioPercentage =>
      _toPercentage(internationalExpenseCount, totalExpenseCount);

  int get domesticRatioPercentage =>
      _toPercentage(domesticExpenseCount, totalExpenseCount);

  static int _toPercentage(int value, int total) {
    if (total <= 0) {
      return 0;
    }
    return ((value / total) * 100).round();
  }
}
