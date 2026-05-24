import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_extension.dart';
import '../../../shared/widgets/insight_card.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../insights/domain/insight.dart';
import '../../reports/domain/report_bucket.dart';
import '../../trips/domain/trip.dart';
import '../../trips/presentation/trip_form_screen.dart';
import '../data/global_report_provider.dart';
import '../domain/global_report_summary.dart';

class GlobalReportsScreen extends ConsumerWidget {
  const GlobalReportsScreen({super.key});

  Future<void> _openTripForm(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push<Trip?>(
      MaterialPageRoute<Trip?>(builder: (_) => const TripFormScreen()),
    );
    ref.invalidate(globalReportProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(globalReportProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.globalReportsTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.globalReportsSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(context.l10n.globalReportsLoadError('$error')),
        ),
        data: (summary) {
          if (!summary.hasTrips) {
            return _EmptyGlobalReportsState(
              onAddTrip: () => _openTripForm(context, ref),
            );
          }
          return _GlobalReportBody(summary: summary);
        },
      ),
    );
  }
}

class _GlobalReportBody extends StatelessWidget {
  const _GlobalReportBody({required this.summary});

  final GlobalReportSummary summary;

  @override
  Widget build(BuildContext context) {
    const sectionGap = SizedBox(height: 16);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (summary.totalTrips == 1) ...[
          const _SingleTripNoteCard(),
          sectionGap,
        ],
        if (summary.totalExpenseCount >= 3 && summary.smartInsights.isNotEmpty) ...[
          _SmartSummaryHeroCard(summary: summary),
          sectionGap,
        ],
        if (summary.behavioralInsights.isNotEmpty) ...[
          _BehavioralInsightsSection(
            insights: summary.behavioralInsights.take(2).toList(growable: false),
          ),
          sectionGap,
        ],
        _SummaryCards(summary: summary),
        sectionGap,
        _OverviewCard(summary: summary),
        sectionGap,
        if (summary.totalBilledByCurrency.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.globalReportsTotalBilled),
          _CurrencyBucketList(buckets: summary.totalBilledByCurrency),
          sectionGap,
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyGlobalReportsState extends StatelessWidget {
  const _EmptyGlobalReportsState({required this.onAddTrip});

  final VoidCallback onAddTrip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.globalReportsZeroTripsTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAddTrip,
              child: Text(context.l10n.tripsAddButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleTripNoteCard extends StatelessWidget {
  const _SingleTripNoteCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.globalReportsSingleTripNote,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SmartSummaryHeroCard extends StatelessWidget {
  const _SmartSummaryHeroCard({required this.summary});

  final GlobalReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryInsight = summary.smartInsights.first;
    final supportingInsights = summary.smartInsights.skip(1).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            // Soft lavender to ultra-light indigo
            const Color(0xFFE6E0F8), // lavender
            const Color(0xFFF3F0FA), // ultra-light indigo tint
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.08), // subtle purple shadow
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB39DDB).withValues(alpha: 0.18), // muted lavender accent
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 20,
                    color: const Color(0xFF7C4DFF), // deep indigo icon
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.globalReportsSmartSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4B3B6B), // deep lavender text
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _localizeInsight(context, primaryInsight),
              style: theme.textTheme.titleMedium?.copyWith(
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4B3B6B), // deep lavender text
              ),
            ),
            if (supportingInsights.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final insight in supportingInsights) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: const Color(0xFFB39DDB).withValues(alpha: 0.75), // muted lavender dot
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _localizeInsight(context, insight),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.34,
                          color: const Color(0xFF4B3B6B), // deep lavender text
                        ),
                      ),
                    ),
                  ],
                ),
                if (insight != supportingInsights.last)
                  const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final GlobalReportSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCountCard(
            title: context.l10n.globalReportsTotalTrips,
            value: summary.totalTrips.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCountCard(
            title: context.l10n.globalReportsActiveTrips,
            value: summary.activeTrips.toString(),
          ),
        ),
      ],
    );
  }
}

class _BehavioralInsightsSection extends StatelessWidget {
  const _BehavioralInsightsSection({required this.insights});

  final List<Insight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            context.l10n.globalReportsBehavioralInsightsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7C4DFF), // indigo accent
              letterSpacing: 0.3,
            ),
          ),
        ),
        for (final insight in insights)
          InsightCard(
            title: _behavioralInsightTitle(context, insight),
            description: _behavioralInsightDescription(context, insight),
            attribution: _behavioralInsightAttribution(context, insight),
          ),
      ],
    );
  }
}

class _SummaryCountCard extends StatelessWidget {
  const _SummaryCountCard({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.summary});

  final GlobalReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.globalReportsOverview,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (summary.uniqueTransactionCurrencyCount > 1 &&
                summary.dominantCurrency != null)
              _OverviewRow(
                label: context.l10n.globalReportsDominantCurrency,
                value: summary.dominantCurrency!,
              ),
            if (summary.uniqueCategoryCount > 1 && summary.dominantCategory != null)
              _OverviewRow(
                label: context.l10n.globalReportsTopCategory,
                value: ExpenseOptionLabels.category(
                  context.l10n,
                  summary.dominantCategory!,
                ),
              ),
            if (summary.uniquePaymentChannelCount > 1 &&
                summary.mostUsedPaymentChannel != null)
              _OverviewRow(
                label: context.l10n.globalReportsMostUsedPaymentChannel,
                value: ExpenseOptionLabels.paymentChannel(
                  context.l10n,
                  summary.mostUsedPaymentChannel!,
                ),
              ),
            if (summary.uniquePaymentNetworkCount > 1 &&
                summary.mostUsedPaymentNetwork != null)
              _OverviewRow(
                label: context.l10n.globalReportsMostUsedPaymentNetwork,
                value: ExpenseOptionLabels.paymentNetwork(
                  context.l10n,
                  summary.mostUsedPaymentNetwork!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

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
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _CurrencyBucketList extends StatelessWidget {
  const _CurrencyBucketList({required this.buckets});

  final List<ReportBucket> buckets;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int index = 0; index < buckets.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buckets[index].currency,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.tripReportsExpenseCountLabel(
                            buckets[index].count,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  _AmountText(
                    amount: buckets[index].totalAmount,
                    currency: buckets[index].currency,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '${_formatAmount(amount)} $currency',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

String _localizeInsight(BuildContext context, GlobalReportInsight insight) {
  switch (insight.type) {
    case GlobalReportInsightType.dominantPaymentChannel:
      return context.l10n.globalReportsInsightDominantPaymentChannel(
        ExpenseOptionLabels.paymentChannel(context.l10n, insight.subject ?? 'Other'),
      );
    case GlobalReportInsightType.dominantCategory:
      return context.l10n.globalReportsInsightDominantCategory(
        ExpenseOptionLabels.category(context.l10n, insight.subject ?? 'Other'),
      );
    case GlobalReportInsightType.averageSpendPerTrip:
      return context.l10n.globalReportsInsightAverageSpendPerTrip(
        '${_formatAmount(insight.amount ?? 0)} ${insight.currency ?? ''}',
      );
    case GlobalReportInsightType.dominantCurrency:
      return context.l10n.globalReportsInsightDominantCurrency(
        insight.subject ?? '',
      );
    case GlobalReportInsightType.currencyDistribution:
      return context.l10n.globalReportsInsightCurrencyDistribution;
    case GlobalReportInsightType.internationalDomesticRatio:
      final internationalPct = insight.percentage ?? 0;
      final domesticPct = 100 - internationalPct;
      return context.l10n.globalReportsInsightIntlDomesticRatio(
        internationalPct,
        domesticPct,
      );
    case GlobalReportInsightType.categoryVariation:
      return context.l10n.globalReportsInsightCategoryVariation;
    case GlobalReportInsightType.paymentVariation:
      return context.l10n.globalReportsInsightPaymentVariation;
  }
}

String _formatAmount(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _behavioralInsightTitle(BuildContext context, Insight insight) {
  return switch (insight.type) {
    InsightType.spike => context.l10n.globalReportsBehavioralInsightTitleSpike,
    InsightType.categoryDrift =>
      context.l10n.globalReportsBehavioralInsightTitleCategoryDrift,
    InsightType.fees => context.l10n.globalReportsBehavioralInsightTitleFees,
  };
}

String _behavioralInsightDescription(BuildContext context, Insight insight) {
  return switch (insight.type) {
    InsightType.spike => _localizeSpikeBehavioralInsight(context, insight),
    InsightType.categoryDrift =>
      context.l10n.globalReportsBehavioralInsightCategoryDrift(
        insight.percentage ?? 0,
        ExpenseOptionLabels.category(context.l10n, insight.category ?? 'Other'),
      ),
    InsightType.fees => context.l10n.globalReportsBehavioralInsightFees(
      insight.percentage ?? 0,
    ),
  };
}

String? _behavioralInsightAttribution(BuildContext context, Insight insight) {
  final tripName = insight.tripName;
  if (tripName == null || tripName.trim().isEmpty) {
    return null;
  }

  final attributionLabel = (insight.contributorTripCount ?? 0) > 1
      ? context.l10n.globalReportsBehavioralInsightAttributionTop
      : context.l10n.globalReportsBehavioralInsightAttributionIn;

  return '$attributionLabel $tripName';
}

String _localizeSpikeBehavioralInsight(BuildContext context, Insight insight) {
  final pct = insight.percentage;
  if (pct == null) {
    return context.l10n.globalReportsBehavioralInsightSpikeLarge;
  }
  if (pct > 300) {
    return context.l10n.globalReportsBehavioralInsightSpikeAbove300;
  }
  if (pct >= 150) {
    return context.l10n.globalReportsBehavioralInsightSpikeNoticeable;
  }
  return context.l10n.globalReportsBehavioralInsightSpike(pct);
}
