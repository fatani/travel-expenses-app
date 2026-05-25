import 'package:flutter/material.dart';

/// Calm typography rhythm tuned for Arabic readability.
class RtlTypography {
  const RtlTypography._();

  static bool isArabicLocale(String languageCode) =>
      languageCode.toLowerCase() == 'ar';

  /// Screen and card titles — moderate, not dashboard-bold.
  static FontWeight titleWeight(bool isArabic) =>
      isArabic ? FontWeight.w600 : FontWeight.w700;

  static double titleLineHeight(bool isArabic) => isArabic ? 1.38 : 1.22;

  static double bodyLineHeight(bool isArabic) => isArabic ? 1.42 : 1.28;

  static double chipLineHeight(bool isArabic) => isArabic ? 1.28 : 1.18;

  /// Section labels inside forms and reports.
  static FontWeight sectionWeight(bool isArabic) =>
      isArabic ? FontWeight.w600 : FontWeight.w700;

  static FontWeight chipWeight(bool isArabic) =>
      isArabic ? FontWeight.w500 : FontWeight.w600;

  /// Hero amount fields: readable without shouting.
  static FontWeight amountWeight(bool isArabic) =>
      isArabic ? FontWeight.w600 : FontWeight.w700;

  static double amountLineHeight(bool isArabic) => isArabic ? 1.18 : 1.12;

  /// Summary totals on report surfaces.
  static FontWeight summaryAmountWeight(bool isArabic) =>
      isArabic ? FontWeight.w700 : FontWeight.w800;
}
