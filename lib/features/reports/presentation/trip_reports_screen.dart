import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/app_surfaces.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/theme/rtl_typography.dart';
import '../../../l10n/l10n_extension.dart';
import '../../../shared/widgets/calm_load_error_panel.dart';
import '../../../shared/widgets/insight_card.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../predictions/data/trip_prediction_provider.dart';
import '../../predictions/domain/trip_prediction_summary.dart';
import '../../predictions/presentation/trip_prediction_section.dart';
import '../../trips/domain/trip.dart';
import '../../trips/domain/trip_title_resolver.dart';
import '../data/trip_report_provider.dart';
import '../domain/report_bucket.dart';
import '../domain/trip_report_summary.dart';
import 'trip_report_cash_wallet_snapshot_slot.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TripReportsScreen extends ConsumerWidget {
  const TripReportsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(tripReportProvider(trip.id));
    final predictionAsync = ref.watch(tripPredictionProvider(trip.id));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          TripTitleResolver.resolve(
            trip,
            Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
          ),
        ),
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
        error: (e, _) => CalmLoadErrorPanel(
          title: context.l10n.tripReportsLoadError,
          retryLabel: context.l10n.commonTryAgain,
          onRetry: () => ref.invalidate(tripReportProvider(trip.id)),
        ),
        data: (summary) => _ReportBody(
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

/// Data-volume thresholds for progressive reporting.
enum _ReportDataTier {
  /// 0 expenses — show empty state.
  empty,

  /// 1–3 expenses — show lightweight summary only.
  low,

  /// 4+ expenses — show full report structure.
  sufficient,
}

_ReportDataTier _dataTier(int count) {
  if (count == 0) return _ReportDataTier.empty;
  if (count <= 3) return _ReportDataTier.low;
  return _ReportDataTier.sufficient;
}

class _ReportBody extends ConsumerWidget {
  const _ReportBody({
    required this.summary,
    required this.predictionSummary,
  });

  final TripReportSummary summary;
  final TripPredictionSummary? predictionSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const sectionGap = SizedBox(height: 20);
    const listPadding = EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    );
    final tier = _dataTier(summary.totalExpenseCount);

    // === Empty state ===
    if (tier == _ReportDataTier.empty) {
      return _EarlyReportEmptyState();
    }

    final categoryCount = _uniqueBucketKeyCount(summary.byCategory);
    final transactionCurrencyCount =
        _uniqueBucketKeyCount(summary.byTransactionCurrency);
    final paymentNetworkCount = _uniqueBucketKeyCount(summary.byPaymentNetwork);
    final paymentChannelCount = _uniqueBucketKeyCount(summary.byPaymentChannel);

    // === Low data: 1–3 expenses — lightweight summary ===
    if (tier == _ReportDataTier.low) {
      return ListView(
        padding: listPadding,
        children: [
          _LightweightSummaryCard(summary: summary),
          sectionGap,
          TripReportCashWalletSnapshotSlot(
            tripId: summary.tripId,
            sectionGap: sectionGap,
          ),
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
          const SizedBox(height: 24),
        ],
      );
    }

    // === Sufficient data: 4+ expenses — full report ===
    return ListView(
      padding: listPadding,
      children: [
        _ReportHeroSummaryCard(
          summary: summary,
          categoryCount: categoryCount,
        ),
        sectionGap,
        TripReportCashWalletSnapshotSlot(
          tripId: summary.tripId,
          sectionGap: sectionGap,
        ),
        if (summary.smartInsights.isNotEmpty) ...[
          _TripInsightsSection(
            insights: summary.smartInsights.take(1).toList(growable: false),
          ),
          sectionGap,
        ],
        if (predictionSummary != null) ...[
          TripPredictionSection(
            summary: predictionSummary!,
            title: context.l10n.tripPredictionSectionTitle,
            burnRateTitle: context.l10n.tripPredictionBurnRateTitle,
            forecastTitle: context.l10n.tripPredictionForecastTitle,
          ),
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
          _CategoryInsightsCard(
            buckets: summary.byCategory,
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
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripReportsOverview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 14),
            _StatRow(
              label: context.l10n.tripReportsTotalExpenses,
              value: summary.totalExpenseCount.toString(),
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

class _ReportHeroSummaryCard extends StatelessWidget {
  const _ReportHeroSummaryCard({
    required this.summary,
    required this.categoryCount,
  });

  final TripReportSummary summary;
  final int categoryCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasMultipleTransactionCurrencies =
        summary.byTransactionCurrency.length > 1;
    final totalBucket =
        summary.topBilledBucket ?? summary.topTransactionCurrencyBucket;
    final totalText = totalBucket == null
        ? '--'
      : '${_formatAmount(totalBucket.totalAmount)} ${totalBucket.currency.trim().toUpperCase()}';
    final spendingLabel = totalBucket == null
        ? '--'
        : hasMultipleTransactionCurrencies
            ? context.l10n.tripDetailsTotalInCurrencyOnly(
                totalBucket.currency.trim().toUpperCase(),
              )
            : context.l10n.tripReportsOverallSpending;
    final topCategoryLabel = summary.topCategory == null
        ? null
        : ExpenseOptionLabels.category(context.l10n, summary.topCategory!);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFEEF0FF),
              const Color(0xFFF6EEFF),
            ],
          ),
          border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  totalText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                spendingLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _HeroMetricChip(
                      value: context.l10n.tripReportsExpenseCountLabel(
                        summary.totalExpenseCount,
                      ),
                    ),
                  ),
                  if (categoryCount > 1) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HeroMetricChip(
                        value: context.l10n.tripReportsHeroCategoryCount(
                          categoryCount,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (topCategoryLabel != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    ),
                  ),
                  child: Text(
                    '${context.l10n.tripReportsTopCategory}: $topCategoryLabel',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Early-state widgets (0 expenses and 1–3 expenses)
// ---------------------------------------------------------------------------

class _EarlyReportEmptyState extends StatelessWidget {
  const _EarlyReportEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.tripReportsEarlyNoExpenses,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LightweightSummaryCard extends StatelessWidget {
  const _LightweightSummaryCard({required this.summary});

  final TripReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final totalBucket =
        summary.topBilledBucket ?? summary.topTransactionCurrencyBucket;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.tripReportsEarlyRecorded(summary.totalExpenseCount),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          if (totalBucket != null) ...[
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                '${_formatAmount(totalBucket.totalAmount)} ${totalBucket.currency.trim().toUpperCase()}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: RtlTypography.summaryAmountWeight(isArabic),
                  letterSpacing: isArabic ? 0 : -0.3,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.l10n.tripReportsEarlyAddMoreHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetricChip extends StatelessWidget {  const _HeroMetricChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
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
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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
              fontWeight: FontWeight.w600,
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
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveStyle = valueStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: effectiveStyle,
            ),
          ),
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
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: AppColors.borderSoft.withValues(alpha: 0.65),
      shadows: AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < buckets.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showKey)
                    Expanded(
                      child: Text(
                        _localizedBucketKey(
                          context,
                          buckets[i].key,
                          groupLabelType,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  _AmountAndCountColumn(
                    amount: buckets[i].totalAmount,
                    currency: buckets[i].currency,
                    countLabel: context.l10n.tripReportsExpenseCountLabel(
                      buckets[i].count,
                    ),
                    compact: true,
                  ),
                ],
              ),
            ),
            if (i < buckets.length - 1) const Divider(height: 1),
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

class _CategoryInsightsCard extends StatelessWidget {
  const _CategoryInsightsCard({
    required this.buckets,
    required this.topGroupKey,
  });

  final List<ReportBucket> buckets;
  final String? topGroupKey;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ReportBucket>>{};
    for (final b in buckets) {
      grouped.putIfAbsent(b.key, () => []).add(b);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        for (final entry in grouped.entries) ...[
          Builder(
            builder: (context) {
              final categoryBuckets = entry.value;
              final primaryBucket = categoryBuckets.first;
              final totalCount = categoryBuckets.fold<int>(
                0,
                (sum, b) => sum + b.count,
              );
              final isTopCategory = entry.key == topGroupKey;

              final backgroundColor = isTopCategory
                  ? const Color(0xFFEFE9FF)
                  : const Color(0xFFFAF8FF);
              final borderColor = isTopCategory
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.16)
                  : const Color(0xFF7C3AED).withValues(alpha: 0.1);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _localizedBucketKey(
                                context,
                                entry.key,
                                _BucketGroupLabelType.category,
                              ),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isTopCategory) const _TopSpendingBadge(),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${_formatAmount(primaryBucket.totalAmount)} ${primaryBucket.currency}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        context.l10n.tripReportsExpenseCountLabel(totalCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (categoryBuckets.length > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.tripReportsCategoryMultiCurrency(
                            categoryBuckets.length,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
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
    final colorScheme = theme.colorScheme;
    final amountStyle = (compact
            ? theme.textTheme.titleSmall
            : theme.textTheme.titleMedium)
        ?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.15,
          color: colorScheme.onSurface,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '${_formatAmount(amount)} ${currency.trim().toUpperCase()}',
            textAlign: TextAlign.end,
            style: amountStyle,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          countLabel,
          textAlign: TextAlign.end,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
            fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE8FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.tripReportsTopSpending,
        style: theme.textTheme.labelSmall?.copyWith(
          color: const Color(0xFF5B3FD0).withValues(alpha: 0.88),
          fontWeight: FontWeight.w600,
          fontSize: 10.5,
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
