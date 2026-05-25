import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Unicode left-to-right isolate (U+2066) and pop directional isolate (U+2069).
const String ltrIsolateStart = '\u2066';
const String ltrIsolateEnd = '\u2069';

/// Wraps [text] so numbers, Latin dates, and currency codes stay readable in RTL.
String wrapLtrIsolate(String text) => '$ltrIsolateStart$text$ltrIsolateEnd';

/// Stable number formatting for amounts shown inside RTL layouts.
class BidiAmountFormat {
  const BidiAmountFormat._();

  static final NumberFormat _number = NumberFormat('#,##0.##', 'en');

  static String formatNumber(double amount) => _number.format(amount);

  static String formatWithCurrency(double amount, String currencyCode) {
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    return '${formatNumber(amount)} $normalizedCurrency';
  }

  static String ltrIsolate(double amount, String currencyCode) =>
      wrapLtrIsolate(formatWithCurrency(amount, currencyCode));

  static String ltrIsolateNumber(double amount) =>
      wrapLtrIsolate(formatNumber(amount));

  /// Approximate converted amount with a stable leading ≈ marker.
  static String formatApproximate(double amount, String currencyCode) =>
      '≈ ${ltrIsolate(amount, currencyCode)}';
}

/// Renders [data] in a fixed LTR direction — use for currency codes, amounts, dates.
class LtrText extends StatelessWidget {
  const LtrText({
    super.key,
    required this.data,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Text(
        data,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      ),
    );
  }
}

/// Embeds an LTR [segment] inside RTL [prefix] without breaking reading order.
String embedLtrInRtl(String prefix, String segment) {
  if (segment.isEmpty) {
    return prefix;
  }
  return '$prefix${wrapLtrIsolate(segment)}';
}
