import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/core/theme/rtl_typography.dart';

void main() {
  group('RtlTypography calm weights', () {
    test('arabic titles are lighter than english', () {
      expect(
        RtlTypography.titleWeight(true).value,
        lessThan(RtlTypography.titleWeight(false).value),
      );
    });

    test('arabic amounts are lighter than english', () {
      expect(
        RtlTypography.amountWeight(true).value,
        lessThan(RtlTypography.amountWeight(false).value),
      );
    });

    test('arabic line heights are taller than english', () {
      expect(
        RtlTypography.titleLineHeight(true),
        greaterThan(RtlTypography.titleLineHeight(false)),
      );
      expect(
        RtlTypography.bodyLineHeight(true),
        greaterThan(RtlTypography.bodyLineHeight(false)),
      );
      expect(
        RtlTypography.chipLineHeight(true),
        greaterThan(RtlTypography.chipLineHeight(false)),
      );
    });

    test('chip weight stays readable but not loud', () {
      expect(RtlTypography.chipWeight(true), FontWeight.w500);
      expect(RtlTypography.chipWeight(false), FontWeight.w600);
    });
  });
}
