import 'package:flutter/material.dart';

import '../../../l10n/l10n_extension.dart';
import '../domain/trip_prediction_summary.dart';

class TripPredictionSection extends StatelessWidget {
  const TripPredictionSection({
    super.key,
    required this.summary,
    required this.title,
    required this.burnRateTitle,
    required this.forecastTitle,
  });

  final TripPredictionSummary summary;
  final String title;
  final String burnRateTitle;
  final String forecastTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final currencies = summary.forecastTotalByCurrency.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  burnRateTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final currency in currencies)
                  _PredictionRow(
                    label: '$currency/day',
                    value:
                        '${_formatAmount(summary.burnRateByCurrency[currency] ?? 0)} $currency',
                  ),
                const SizedBox(height: 12),
                Text(
                  forecastTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tripPredictionRemainingDays(summary.remainingDays),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final currency in currencies)
                  _PredictionRow(
                    label: currency,
                    value:
                        '${_formatAmount(summary.forecastTotalByCurrency[currency] ?? 0)} $currency',
                  ),
              ],
            ),
          ),
        ),
        if (summary.hasBudgetWarning) ...[
          const SizedBox(height: 10),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                l10n.tripPredictionBudgetWarning,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
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
