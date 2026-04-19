import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../../../l10n/l10n_extension.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../reports/domain/report_bucket.dart';
import '../data/global_report_calculator.dart';
import '../domain/global_report_summary.dart';

final _globalReportProvider = FutureProvider<GlobalReportSummary>((ref) async {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final expenseRepository = ref.watch(expenseRepositoryProvider);

  final trips = await tripRepository.getTrips();
  final expenseLists = await Future.wait(
    trips.map((trip) => expenseRepository.getExpensesByTrip(trip.id)),
  );
  final expenses = expenseLists.expand((items) => items).toList(growable: false);

  const calculator = GlobalReportCalculator();
  return calculator.calculate(trips: trips, expenses: expenses);
});

class GlobalReportsScreen extends ConsumerWidget {
  const GlobalReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(_globalReportProvider);
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
            return const _EmptyGlobalReportsState();
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
    const sectionGap = SizedBox(height: 20);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (summary.smartInsights.isNotEmpty) ...[
          _SmartInsightsCard(summary: summary),
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
        if (summary.averageSpendPerTripByCurrency.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.globalReportsAveragePerTrip),
          _CurrencyMetricList(metrics: summary.averageSpendPerTripByCurrency),
          sectionGap,
        ],
        if (summary.averageDailySpendByCurrency.isNotEmpty) ...[
          _SectionHeader(title: context.l10n.globalReportsAveragePerDay),
          _CurrencyMetricList(metrics: summary.averageDailySpendByCurrency),
          sectionGap,
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _EmptyGlobalReportsState extends StatelessWidget {
  const _EmptyGlobalReportsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              context.l10n.globalReportsEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.globalReportsEmptyMessage,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartInsightsCard extends StatelessWidget {
  const _SmartInsightsCard({required this.summary});

  final GlobalReportSummary summary;

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
              context.l10n.globalReportsSmartSummary,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final insight in summary.smartInsights) ...[
              Text(
                _localizeInsight(context, insight),
                style: theme.textTheme.bodyMedium,
              ),
              if (insight != summary.smartInsights.last)
                const SizedBox(height: 8),
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
            value: summary.totalTripCount.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCountCard(
            title: context.l10n.globalReportsTotalExpenses,
            value: summary.totalExpenseCount.toString(),
          ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.globalReportsOverview,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _OverviewRow(
              label: context.l10n.globalReportsInternationalRatio,
              value: '${summary.internationalRatioPercentage}%',
            ),
            _OverviewRow(
              label: context.l10n.globalReportsDomesticRatio,
              value: '${summary.domesticRatioPercentage}%',
            ),
            if (summary.trackedTripDays > 0)
              _OverviewRow(
                label: context.l10n.globalReportsTrackedDays,
                value: summary.trackedTripDays.toString(),
              ),
            if (summary.dominantCurrency != null)
              _OverviewRow(
                label: context.l10n.globalReportsDominantCurrency,
                value: summary.dominantCurrency!,
              ),
            if (summary.dominantCategory != null)
              _OverviewRow(
                label: context.l10n.globalReportsTopCategory,
                value: ExpenseOptionLabels.category(
                  context.l10n,
                  summary.dominantCategory!,
                ),
              ),
            if (summary.mostUsedPaymentChannel != null)
              _OverviewRow(
                label: context.l10n.globalReportsMostUsedPaymentChannel,
                value: ExpenseOptionLabels.paymentChannel(
                  context.l10n,
                  summary.mostUsedPaymentChannel!,
                ),
              ),
            if (summary.mostUsedPaymentNetwork != null)
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
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
            ListTile(
              dense: true,
              title: Text(buckets[index].currency),
              subtitle: Text(
                context.l10n.tripReportsExpenseCountLabel(buckets[index].count),
              ),
              trailing: _AmountText(
                amount: buckets[index].totalAmount,
                currency: buckets[index].currency,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrencyMetricList extends StatelessWidget {
  const _CurrencyMetricList({required this.metrics});

  final List<GlobalCurrencyMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (int index = 0; index < metrics.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              dense: true,
              title: Text(metrics[index].currency),
              trailing: _AmountText(
                amount: metrics[index].amount,
                currency: metrics[index].currency,
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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '${_formatAmount(amount)} $currency',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
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
        insight.percentage ?? 0,
      );
  }
}

String _formatAmount(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}
