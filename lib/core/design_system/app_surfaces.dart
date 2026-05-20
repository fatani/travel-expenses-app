import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.borderSoft,
    this.radius = AppRadius.md,
    this.shadows,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;
  final Color borderColor;
  final double radius;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: AppBorderWidth.thin),
        boxShadow: shadows ?? AppShadows.soft,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class AppBottomSheetContainer extends StatelessWidget {
  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.md, 10, AppSpacing.md, AppSpacing.md),
    this.minHeight = 360,
    this.maxHeightFactor = 0.9,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minHeight;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * maxHeightFactor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight,
          maxHeight: maxHeight,
          minWidth: double.infinity,
        ),
        child: Material(
          color: AppColors.surfaceElevated,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
