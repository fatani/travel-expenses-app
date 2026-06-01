import 'package:flutter/material.dart';

import '../../../core/design_system/app_surfaces.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../l10n/l10n_extension.dart';
import '../../cash_wallet/domain/trip_cash_balance.dart';

/// Read-only cash-on-hand snapshot for the trip report.
class TripReportCashWalletSnapshot extends StatelessWidget {
  const TripReportCashWalletSnapshot({
    super.key,
    required this.balances,
  });

  final List<TripCashBalance> balances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const Key('trip_report_cash_wallet_snapshot'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            context.l10n.tripSetupCashTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          borderColor: AppColors.borderSoft.withValues(alpha: 0.65),
          shadows: AppShadows.soft,
          child: Column(
            children: [
              for (var i = 0; i < balances.length; i++) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          balances[i].currencyCode.trim().toUpperCase(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${_formatAmount(balances[i].balanceAmount)} ${balances[i].currencyCode.trim().toUpperCase()}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.15,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < balances.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

String _formatAmount(double amount) {
  if (amount == amount.truncateToDouble()) {
    return amount.toStringAsFixed(0);
  }
  return amount.toStringAsFixed(2);
}
