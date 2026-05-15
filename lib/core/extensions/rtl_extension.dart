import 'package:flutter/material.dart';

/// Extension to easily check RTL/LTR direction across the app.
extension RTLBuildContext on BuildContext {
  /// Returns true if current layout direction is RTL (Arabic, Hebrew, etc.)
  bool get isRTL => Directionality.of(this) == TextDirection.rtl;

  /// Returns true if current layout direction is LTR (English, etc.)
  bool get isLTR => Directionality.of(this) == TextDirection.ltr;
}
