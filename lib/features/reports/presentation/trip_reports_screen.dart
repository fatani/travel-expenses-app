import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../l10n/l10n_extension.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../trips/domain/trip.dart';
import '../data/trip_report_calculator.dart';
import '../domain/report_bucket.dart';
import '../domain/trip_report_summary.dart';

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _tripReportProvider =
    FutureProvider.family<TripReportSummary, Trip>((ref, trip) async {
  final repo = ref.watch(expenseRepositoryProvider);
  final expenses = await repo.getExpensesByTrip(trip.id);
  const calculator = TripReportCalculator();
  return calculator.calculate(
    tripId: trip.id,
    tripName: trip.name,
    expenses: expenses,
  );
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TripReportsScreen extends ConsumerWidget {
  const TripReportsScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_tripReportProvider(trip));
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
        data: (summary) => _ReportBody(summary: summary),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.summary});

  final TripReportSummary summary;

  @override
  Widget build(BuildContext context) {
    const sectionGap = SizedBox(height: 20);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (summary.smartInsights.isNotEmpty) ...[
          _SmartSummaryCard(summary: summary),
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
        if (summary.byCategory.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.tripReportsByCategory),
          _GroupedBucketCard(
            buckets: summary.byCategory,
            groupLabelType: _BucketGroupLabelType.category,
            topGroupKey: summary.topCategory,
          ),
          sectionGap,
        ],
        if (summary.byTransactionCurrency.isNotEmpty) ...[
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
        if (summary.byPaymentNetwork.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.tripReportsByPaymentNetwork),
          _GroupedBucketCard(
            buckets: summary.byPaymentNetwork,
            groupLabelType: _BucketGroupLabelType.paymentNetwork,
            topGroupKey: null,
          ),
          sectionGap,
        ],
        if (summary.byPaymentChannel.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.tripReportsByPaymentChannel),
          _GroupedBucketCard(
            buckets: summary.byPaymentChannel,
            groupLabelType: _BucketGroupLabelType.paymentChannel,
            topGroupKey: summary.topPaymentChannel,
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

class _SmartSummaryCard extends StatelessWidget {
  const _SmartSummaryCard({required this.summary});

  final TripReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tripReportsSmartSummary,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final insight in summary.smartInsights) ...[
              _InsightLine(text: _localizeInsight(context, insight)),
              if (insight != summary.smartInsights.last)
                const SizedBox(height: 8),
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
                      if (entry.key == topGroupKey) const _TopSpendingBadge(),
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
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            '${_formatAmount(amount)} $currency',
            textAlign: TextAlign.end,
            style: amountStyle,
          ),
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

String _localizeInsight(BuildContext context, TripReportInsight insight) {
  switch (insight.type) {
    case TripReportInsightType.multipleCurrencies:
      return context.l10n.tripReportsInsightMultipleCurrencies(
        insight.percentage ?? 0,
      );
    case TripReportInsightType.internationalDominant:
      return context.l10n.tripReportsInsightInternationalDominant;
    case TripReportInsightType.feesPercentage:
      return context.l10n.tripReportsInsightFeesPercentage(
        insight.percentage ?? 0,
      );
    case TripReportInsightType.noInternationalFees:
      return context.l10n.tripReportsInsightNoInternationalFees;
    case TripReportInsightType.dominantCurrency:
      return context.l10n.tripReportsInsightDominantCurrency(
        insight.subject ?? '',
        insight.percentage ?? 0,
      );
    case TripReportInsightType.topCategory:
      return context.l10n.tripReportsInsightTopCategory(
        ExpenseOptionLabels.category(context.l10n, insight.subject ?? 'Other'),
      );
    case TripReportInsightType.dominantPaymentChannel:
      return context.l10n.tripReportsInsightDominantPaymentChannel(
        ExpenseOptionLabels.paymentChannel(context.l10n, insight.subject ?? 'Other'),
        insight.percentage ?? 0,
      );
    case TripReportInsightType.dominantTripTypeShare:
      if (insight.isInternational == true) {
        return context.l10n.tripReportsInsightInternationalShare(
          insight.percentage ?? 0,
        );
      }
      return context.l10n.tripReportsInsightDomesticShare(
        insight.percentage ?? 0,
      );
  }
}

class _InsightLine extends StatelessWidget {
  const _InsightLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

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
