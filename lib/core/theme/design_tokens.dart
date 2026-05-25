import 'package:flutter/material.dart';

class AppRadius {
  const AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double sheet = 28;
  static const double pill = 999;
}

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppBorderWidth {
  const AppBorderWidth._();

  static const double thin = 1;
  static const double regular = 1.25;
}

class AppDurations {
  const AppDurations._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

class AppComponentSizes {
  const AppComponentSizes._();

  static const double dialogIconContainer = 38;
  static const double dialogIcon = 18;
  static const double dialogDestructiveButtonMinHeight = 46;
}

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceElevated = Color(0xFFFCFAFF);
  static const Color surfaceLavender = Color(0xFFF7F2FF);
  static const Color primary = Color(0xFF6D28D9);
  static const Color primaryDeep = Color(0xFF4C1D95);
  static const Color primarySoft = Color(0xFFEDE9FE);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color borderSoft = Color(0xFFE9D5FF);
  static const Color borderMuted = Color(0xFFD6BBFB);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color destructive = Color(0xFFB42318);
  static const Color destructiveSoft = Color(0xFFFEE4E2);
  static const Color warningSoft = Color(0xFFFFF7ED);
  static const Color warningBorder = Color(0xFFFED7AA);
  static const Color successSoft = Color(0xFFECFDF3);
}

class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.018),
          blurRadius: 6,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get modal => [
        BoxShadow(
          color: const Color(0xFF4C1D95).withValues(alpha: 0.10),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ];
}

class AppTypography {
  const AppTypography._();

  static TextStyle title(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ) ??
      const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.45,
          ) ??
      const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        height: 1.45,
      );

  static TextStyle label(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryDeep,
          ) ??
      const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryDeep,
      );
}
