import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/rtl_typography.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor = AppColors.surfaceLavender,
    this.foregroundColor = AppColors.primaryDeep,
  });

  final String label;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: isArabic ? AppSpacing.xs + 1 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foregroundColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: RtlTypography.chipWeight(isArabic),
                  height: RtlTypography.chipLineHeight(isArabic),
                ),
          ),
        ],
      ),
    );
  }
}

class CurrencyChip extends StatelessWidget {
  const CurrencyChip({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return AppChip(
      label: code.trim().toUpperCase(),
      icon: Icons.currency_exchange_outlined,
    );
  }
}
