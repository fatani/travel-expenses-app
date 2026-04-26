import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../domain/trip_prediction_summary.dart';

class TripPredictionSection extends StatelessWidget {
  const TripPredictionSection({super.key, required this.summary});

  final TripPredictionSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencies = summary.totalSpendByCurrency.keys.toList()..sort();
    final uniqueActions = summary.actions
        .fold<List<TripDecisionAction>>(<TripDecisionAction>[], (acc, action) {
          final exists = acc.any(
            (existing) =>
                existing.type == action.type &&
                existing.category == action.category,
          );
          if (!exists) {
            acc.add(action);
          }
          return acc;
        })
        .take(2)
        .toList(growable: false);
    final hasSpendSpike = uniqueActions.any(
      (action) => action.type == TripDecisionActionType.spendSpike,
    );
    if (currencies.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summary.isTripEnded
                  ? '📊 ملخص الصرف والتوصيات'
                  : '📊 التوقعات والتوصيات',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            for (int index = 0; index < currencies.length; index++) ...[
              _CurrencyPredictionBlock(
                currency: currencies[index],
                isTripEnded: summary.isTripEnded,
                currentSpend:
                    summary.totalSpendByCurrency[currencies[index]] ?? 0,
                burnRate: summary.burnRateByCurrency[currencies[index]] ?? 0,
                forecast:
                    summary.forecastTotalByCurrency[currencies[index]] ?? 0,
                remainingDays: summary.remainingDays,
                hasSpendSpike: hasSpendSpike,
              ),
              if (index < currencies.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
            ],
            if (uniqueActions.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                'التوصيات المقترحة',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (int index = 0; index < uniqueActions.length; index++) ...[
                _ActionLine(
                  message: _actionMessage(context, uniqueActions[index]),
                ),
                if (index < uniqueActions.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrencyPredictionBlock extends StatelessWidget {
  const _CurrencyPredictionBlock({
    required this.currency,
    required this.isTripEnded,
    required this.currentSpend,
    required this.burnRate,
    required this.forecast,
    required this.remainingDays,
    required this.hasSpendSpike,
  });

  final String currency;
  final bool isTripEnded;
  final double currentSpend;
  final double burnRate;
  final double forecast;
  final int remainingDays;
  final bool hasSpendSpike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currency,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _PredictionRow(
          label: 'أنفقت حتى الآن',
          value: '${_formatAmount(currentSpend)} $currency',
        ),
        _PredictionRow(
          label: 'معدل الصرف اليومي',
          value: '${_formatAmount(burnRate)} $currency',
        ),
        if (hasSpendSpike)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'هذا الارتفاع مرتبط بزيادة الإنفاق في نهاية الرحلة.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (!isTripEnded)
          _PredictionRow(
            label: 'المتوقع بنهاية الرحلة',
            value: '${_formatAmount(forecast)} $currency',
          ),
        if (!isTripEnded && remainingDays > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'باقي $remainingDays أيام على نهاية الرحلة',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2, end: 8),
          child: Icon(
            Icons.subdirectory_arrow_left_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.label, required this.value});

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
          Text(label, style: theme.textTheme.bodyMedium),
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

String _formatAmount(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}

String _actionMessage(BuildContext context, TripDecisionAction action) {
  return switch (action.type) {
    TripDecisionActionType.burnRisk =>
      'بهذا المعدل، قد يرتفع إجمالي إنفاقك بشكل ملحوظ قبل نهاية الرحلة.',
    TripDecisionActionType.spendSpike =>
      'إنفاقك في النصف الثاني أعلى بنسبة ${action.percentage ?? 50}%، وهذا يرفع معدل الصرف اليومي. حاول تقليل المشتريات غير الأساسية في الأيام القادمة.',
    TripDecisionActionType.categoryConcentration =>
      'أكثر من ${action.percentage ?? 50}% من إنفاقك كان على ${ExpenseOptionLabels.category(context.l10n, action.category ?? 'Other')}، راجع هذه الفئة أولاً لتقليل المصاريف.',
  };
}
