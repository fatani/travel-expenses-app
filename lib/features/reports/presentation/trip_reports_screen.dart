import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../shared/widgets/insight_card.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../predictions/data/trip_prediction_provider.dart';
import '../../predictions/domain/trip_prediction_summary.dart';
import '../../predictions/presentation/trip_prediction_section.dart';
import '../../trips/domain/trip.dart';
import '../data/trip_report_provider.dart';
import '../domain/report_bucket.dart';
import '../domain/trip_report_summary.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TripReportsScreen extends ConsumerWidget {
  const TripReportsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(tripReportProvider(trip));
    final predictionAsync = ref.watch(tripPredictionProvider(trip));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(
            context.l10n.tripReportsSummarySubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(context.l10n.tripReportsLoadError('$e')),
        ),
        data: (summary) => _ReportBody(
          trip: trip,
          summary: summary,
          predictionSummary: predictionAsync.valueOrNull,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.trip,
    required this.summary,
    required this.predictionSummary,
  });

  final Trip trip;
  final TripReportSummary summary;
  final TripPredictionSummary? predictionSummary;

  @override
  Widget build(BuildContext context) {
    const sectionGap = SizedBox(height: 20);
    final categoryCount = _uniqueBucketKeyCount(summary.byCategory);
    final transactionCurrencyCount =
        _uniqueBucketKeyCount(summary.byTransactionCurrency);
    final paymentNetworkCount = _uniqueBucketKeyCount(summary.byPaymentNetwork);
    final paymentChannelCount = _uniqueBucketKeyCount(summary.byPaymentChannel);
    final shouldShowPrediction =
        predictionSummary != null &&
        summary.totalExpenseCount >= 3 &&
      predictionSummary!.elapsedDays >= 2;
    final budgetStatus = _buildBudgetStatus(
      trip: trip,
      summary: summary,
      predictionSummary: predictionSummary,
    );

    _debugPredictionVisibility(
      expenseCount: summary.totalExpenseCount,
      predictionSummary: predictionSummary,
      shouldShowPrediction: shouldShowPrediction,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (summary.smartInsights.isNotEmpty) ...[
          _TripInsightsSection(
            insights: summary.smartInsights.take(1).toList(growable: false),
          ),
          sectionGap,
        ],
        if (shouldShowPrediction) ...[
          TripPredictionSection(
            summary: predictionSummary!,
          ),
          sectionGap,
        ],
        if (budgetStatus != null) ...[
          _BudgetSection(status: budgetStatus),
          sectionGap,
        ],
        _OverviewCard(summary: summary),
        sectionGap,
        if (summary.totalBilledByCurrency.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.tripReportsTotalBilled),
          _BucketList(
            buckets: summary.totalBilledByCurrency,
            showKey: false,
            groupLabelType: _BucketGroupLabelType.none,
            topKey: null,
            topCurrency: null,
          ),
          sectionGap,
        ],
        if (summary.hasFees) ...[
          _SectionHeader(title: context.l10n.tripReportsTotalFees),
          _BucketList(
            buckets: summary.totalFeesByCurrency,
            showKey: false,
            groupLabelType: _BucketGroupLabelType.none,
            topKey: null,
            topCurrency: null,
          ),
          sectionGap,
        ],
        if (summary.byCategory.isNotEmpty && categoryCount > 1) ...[
          _SectionHeader(title: context.l10n.tripReportsByCategory),
          _GroupedBucketCard(
            buckets: summary.byCategory,
            groupLabelType: _BucketGroupLabelType.category,
            topGroupKey: summary.topCategory,
          ),
          sectionGap,
        ],
        if (summary.byTransactionCurrency.isNotEmpty &&
            transactionCurrencyCount > 1) ...[
          _SectionHeader(
            title: context.l10n.tripReportsByTransactionCurrency,
          ),
          _BucketList(
            buckets: summary.byTransactionCurrency,
            groupLabelType: _BucketGroupLabelType.none,
            topKey: null,
            topCurrency: null,
          ),
          sectionGap,
        ],
        if (summary.byPaymentNetwork.isNotEmpty && paymentNetworkCount > 1) ...[
          _SectionHeader(title: context.l10n.tripReportsByPaymentNetwork),
          _GroupedBucketCard(
            buckets: summary.byPaymentNetwork,
            groupLabelType: _BucketGroupLabelType.paymentNetwork,
            topGroupKey: null,
          ),
          sectionGap,
        ],
        if (summary.byPaymentChannel.isNotEmpty && paymentChannelCount > 1) ...[
          _SectionHeader(title: context.l10n.tripReportsByPaymentChannel),
          _GroupedBucketCard(
            buckets: summary.byPaymentChannel,
            groupLabelType: _BucketGroupLabelType.paymentChannel,
            topGroupKey: null,
          ),
          sectionGap,
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overview card
// ---------------------------------------------------------------------------

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final TripReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripReportsOverview,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _StatRow(
              label: context.l10n.tripReportsTotalExpenses,
              value: summary.totalExpenseCount.toString(),
            ),
            _StatRow(
              label: context.l10n.tripReportsDomestic,
              value: summary.domesticExpenseCount.toString(),
            ),
            if (summary.hasInternational)
              _StatRow(
                label: context.l10n.tripReportsInternational,
                value: summary.internationalExpenseCount.toString(),
                valueColor: colorScheme.primary,
              ),
            if (summary.topCategory != null) ...[
              const Divider(height: 20),
              _StatRow(
                label: context.l10n.tripReportsTopCategory,
                value: ExpenseOptionLabels.category(
                  context.l10n,
                  summary.topCategory!,
                ),
                valueStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section helpers
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        textAlign: TextAlign.start,
        style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
      ),
    );
  }
}

enum _BudgetWarningLevel {
  nearLimit,
  forecastRisk,
  exceeded,
}

class _BudgetStatus {
  const _BudgetStatus({
    required this.budgetAmount,
    required this.budgetCurrency,
    required this.canCompare,
    this.currentSpend,
    this.forecastSpend,
    this.usedPercentage,
    this.warningLevel,
  });

  final double budgetAmount;
  final String budgetCurrency;
  final bool canCompare;
  final double? currentSpend;
  final double? forecastSpend;
  final int? usedPercentage;
  final _BudgetWarningLevel? warningLevel;
}

class _BudgetSection extends StatelessWidget {
  const _BudgetSection({required this.status});

  final _BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warningLevel = status.warningLevel;
    final hasWarning = warningLevel != null;
    final warningColors = _warningColors(theme, warningLevel);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripReportsBudgetTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _StatRow(
              label: context.l10n.tripReportsBudgetAmountLabel,
              value: _formatMoney(status.budgetAmount, status.budgetCurrency),
            ),
            if (status.canCompare) ...[
              _StatRow(
                label: context.l10n.tripReportsBudgetCurrentSpendLabel,
                value: _formatMoney(status.currentSpend ?? 0, status.budgetCurrency),
              ),
              _StatRow(
                label: context.l10n.tripReportsBudgetUsageLabel,
                value: '${status.usedPercentage ?? 0}%',
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.tripReportsBudgetCurrencyMismatch,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (hasWarning) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: warningColors.$1,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _warningMessage(context, status),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: warningColors.$2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TripInsightsSection extends StatelessWidget {
  const _TripInsightsSection({
    required this.insights,
  });

  final List<TripReportInsight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.l10n.globalReportsBehavioralInsightsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        for (final insight in insights)
          InsightCard(
            title: _tripInsightTitle(context, insight),
            description: _tripInsightDescription(context, insight),
            attribution: null,
          ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueStyle,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = valueStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: valueColor ?? theme.colorScheme.onSurface,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(value, style: effectiveStyle),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat bucket list (for billed / fee totals)
// ---------------------------------------------------------------------------

class _BucketList extends StatelessWidget {
  const _BucketList({
    required this.buckets,
    this.showKey = true,
    required this.groupLabelType,
    this.topKey,
    this.topCurrency,
  });

  final List<ReportBucket> buckets;
  final bool showKey;
  final _BucketGroupLabelType groupLabelType;
  final String? topKey;
  final String? topCurrency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < buckets.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              dense: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    showKey
                        ? _localizedBucketKey(
                            context,
                            buckets[i].key,
                            groupLabelType,
                          )
                        : buckets[i].currency,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_isTopBucket(buckets[i])) ...[
                    const SizedBox(height: 4),
                    const _TopSpendingBadge(),
                  ],
                ],
              ),
              trailing: _AmountAndCountColumn(
                amount: buckets[i].totalAmount,
                currency: buckets[i].currency,
                countLabel:
                    context.l10n.tripReportsExpenseCountLabel(buckets[i].count),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped bucket card (key may appear multiple times for different currencies)
// ---------------------------------------------------------------------------

class _GroupedBucketCard extends StatelessWidget {
  const _GroupedBucketCard({
    required this.buckets,
    required this.groupLabelType,
    this.topGroupKey,
  });

  final List<ReportBucket> buckets;
  final _BucketGroupLabelType groupLabelType;
  final String? topGroupKey;

  @override
  Widget build(BuildContext context) {
    // Group by key so same category/network/channel appears together
    final grouped = <String, List<ReportBucket>>{};
    for (final b in buckets) {
      grouped.putIfAbsent(b.key, () => []).add(b);
    }

    final theme = Theme.of(context);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in grouped.entries) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _localizedBucketKey(
                            context,
                            entry.key,
                            groupLabelType,
                          ),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (groupLabelType == _BucketGroupLabelType.category &&
                          entry.key == topGroupKey)
                        const _TopSpendingBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  for (final b in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _AmountAndCountColumn(
                          amount: b.totalAmount,
                          currency: b.currency,
                          countLabel:
                              context.l10n.tripReportsExpenseCountLabel(b.count),
                          compact: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _AmountAndCountColumn extends StatelessWidget {
  const _AmountAndCountColumn({
    required this.amount,
    required this.currency,
    required this.countLabel,
    this.compact = false,
  });

  final double amount;
  final String currency;
  final String countLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amountStyle = (compact
            ? theme.textTheme.bodyMedium
            : theme.textTheme.titleSmall)
        ?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatAmount(amount)} $currency',
          textAlign: TextAlign.end,
          style: amountStyle,
        ),
        const SizedBox(height: 2),
        Text(
          countLabel,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TopSpendingBadge extends StatelessWidget {
  const _TopSpendingBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.tripReportsTopSpending,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Formatting utilities
// ---------------------------------------------------------------------------

String _formatAmount(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

extension on _BucketList {
  bool _isTopBucket(ReportBucket bucket) {
    return bucket.key == topKey && bucket.currency == topCurrency;
  }
}

enum _BucketGroupLabelType {
  none,
  category,
  paymentNetwork,
  paymentChannel,
}

String _localizedBucketKey(
  BuildContext context,
  String key,
  _BucketGroupLabelType type,
) {
  final l10n = context.l10n;
  switch (type) {
    case _BucketGroupLabelType.category:
      return ExpenseOptionLabels.category(l10n, key);
    case _BucketGroupLabelType.paymentNetwork:
      return ExpenseOptionLabels.paymentNetwork(l10n, key);
    case _BucketGroupLabelType.paymentChannel:
      return ExpenseOptionLabels.paymentChannel(l10n, key);
    case _BucketGroupLabelType.none:
      return key;
  }
}

String _tripInsightTitle(BuildContext context, TripReportInsight insight) {
  return switch (insight.type) {
    TripReportInsightType.spike =>
      context.l10n.globalReportsBehavioralInsightTitleSpike,
    TripReportInsightType.categoryDrift =>
      context.l10n.globalReportsBehavioralInsightTitleCategoryDrift,
    TripReportInsightType.feesPercentage =>
      context.l10n.globalReportsBehavioralInsightTitleFees,
    _ => context.l10n.globalReportsBehavioralInsightsTitle,
  };
}

String _tripInsightDescription(
  BuildContext context,
  TripReportInsight insight,
) {
  return switch (insight.type) {
    TripReportInsightType.spike => insight.percentage == null
        ? context.l10n.globalReportsBehavioralInsightSpikeLarge
        : (insight.percentage! > 300
            ? context.l10n.globalReportsBehavioralInsightSpikeAbove300
            : (insight.percentage! >= 150
                ? context.l10n.globalReportsBehavioralInsightSpikeNoticeable
                : context.l10n.globalReportsBehavioralInsightSpike(
                    insight.percentage!,
                  ))),
    TripReportInsightType.categoryDrift =>
      context.l10n.globalReportsBehavioralInsightCategoryDrift(
        insight.percentage ?? 0,
        ExpenseOptionLabels.category(context.l10n, insight.subject ?? 'Other'),
      ),
    TripReportInsightType.feesPercentage => context.l10n.globalReportsBehavioralInsightFees(
      insight.percentage ?? 0,
    ),
    _ => '',
  };
}

int _uniqueBucketKeyCount(List<ReportBucket> buckets) {
  return buckets.map((bucket) => bucket.key).toSet().length;
}

_BudgetStatus? _buildBudgetStatus({
  required Trip trip,
  required TripReportSummary summary,
  required TripPredictionSummary? predictionSummary,
}) {
  final budgetAmount = trip.budget;
  if (budgetAmount == null || budgetAmount <= 0) {
    return null;
  }

  final budgetCurrency = (trip.budgetCurrency ?? trip.baseCurrency).trim().toUpperCase();
  if (budgetCurrency.isEmpty) {
    return null;
  }

  ReportBucket? matchingBucket;
  for (final bucket in summary.totalBilledByCurrency) {
    if (bucket.currency.toUpperCase() == budgetCurrency) {
      matchingBucket = bucket;
      break;
    }
  }

  final hasMatchingSpend = matchingBucket != null;
  final canCompare = hasMatchingSpend || summary.totalExpenseCount == 0;
  if (!canCompare) {
    return _BudgetStatus(
      budgetAmount: budgetAmount,
      budgetCurrency: budgetCurrency,
      canCompare: false,
    );
  }

  final currentSpend = matchingBucket?.totalAmount ?? 0.0;
  final usedPercentage = ((currentSpend / budgetAmount) * 100).round();
  final forecastSpend = predictionSummary?.forecastTotalByCurrency[budgetCurrency];

  _BudgetWarningLevel? warningLevel;
  if (currentSpend >= budgetAmount) {
    warningLevel = _BudgetWarningLevel.exceeded;
  } else if ((predictionSummary?.isTripEnded ?? true) == false &&
      forecastSpend != null &&
      forecastSpend > budgetAmount) {
    warningLevel = _BudgetWarningLevel.forecastRisk;
  } else if (usedPercentage >= 80) {
    warningLevel = _BudgetWarningLevel.nearLimit;
  }

  return _BudgetStatus(
    budgetAmount: budgetAmount,
    budgetCurrency: budgetCurrency,
    canCompare: true,
    currentSpend: currentSpend,
    forecastSpend: forecastSpend,
    usedPercentage: usedPercentage,
    warningLevel: warningLevel,
  );
}

String _warningMessage(BuildContext context, _BudgetStatus status) {
  return switch (status.warningLevel) {
    _BudgetWarningLevel.nearLimit =>
      context.l10n.tripReportsBudgetWarningNearLimit,
    _BudgetWarningLevel.forecastRisk =>
      context.l10n.tripReportsBudgetWarningForecast,
    _BudgetWarningLevel.exceeded =>
      context.l10n.tripReportsBudgetWarningExceeded,
    null => '',
  };
}

(Color, Color) _warningColors(ThemeData theme, _BudgetWarningLevel? level) {
  return switch (level) {
    _BudgetWarningLevel.nearLimit => (
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      ),
    _BudgetWarningLevel.forecastRisk || _BudgetWarningLevel.exceeded => (
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
    null => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
      ),
  };
}

String _formatMoney(double amount, String currency) {
  final formatter = NumberFormat.currency(
    name: currency,
    symbol: '$currency ',
    decimalDigits: amount == amount.truncateToDouble() ? 0 : 2,
  );
  return formatter.format(amount);
}

void _debugPredictionVisibility({
  required int expenseCount,
  required TripPredictionSummary? predictionSummary,
  required bool shouldShowPrediction,
}) {
  debugPrint(
    '[TripReportScreen] '
    'expenses=$expenseCount '
    'summaryNull=${predictionSummary == null} '
    'elapsed=${predictionSummary?.elapsedDays ?? -1} '
    'remaining=${predictionSummary?.remainingDays ?? -1} '
    'tripEnded=${predictionSummary?.isTripEnded ?? false} '
    'burnRates=${predictionSummary?.burnRateByCurrency.length ?? 0} '
    'forecasts=${predictionSummary?.forecastTotalByCurrency.length ?? 0} '
    'actions=${predictionSummary?.actions.length ?? 0} '
    'show=$shouldShowPrediction',
  );
}
