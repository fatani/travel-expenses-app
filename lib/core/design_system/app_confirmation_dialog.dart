import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'app_buttons.dart';

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
    this.icon,
  });

  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: AppShadows.modal,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8B4FE),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: AppComponentSizes.dialogIconContainer,
                    height: AppComponentSizes.dialogIconContainer,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      icon,
                      size: AppComponentSizes.dialogIcon,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(title, style: AppTypography.title(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md + 2),
            Text(message, style: AppTypography.body(context)),
            const SizedBox(height: AppSpacing.lg - 2),
            AppSecondaryButton(onPressed: onCancel, child: Text(cancelLabel)),
            const SizedBox(height: AppSpacing.sm - 2),
            AppDestructiveButton(onPressed: onConfirm, label: confirmLabel),
          ],
        ),
      ),
    );
  }
}
