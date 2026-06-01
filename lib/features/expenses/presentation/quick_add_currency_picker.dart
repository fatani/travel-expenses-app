import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/formatting/bidi_format.dart';
import 'quick_add_currency.dart';

/// Compact currency picker for Quick Add (trip + recent + other).
Future<String?> showQuickAddCurrencyPicker({
  required BuildContext context,
  required QuickAddCurrencyPickerOptions options,
  required String selectedCode,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final code in options.tripCurrencies)
                _QuickAddCurrencyTile(
                  code: code,
                  selected: code == selectedCode,
                  onTap: () => Navigator.of(sheetContext).pop(code),
                ),
              for (final code in options.recentCurrencies)
                _QuickAddCurrencyTile(
                  code: code,
                  selected: code == selectedCode,
                  onTap: () => Navigator.of(sheetContext).pop(code),
                ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                key: const ValueKey('quick_add_currency_option_other'),
                title: Text(
                  AppLocalizations.of(sheetContext)!.quickAddCurrencyPickerOther,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF94A3B8),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(kQuickAddCurrencyPickerOther),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _QuickAddCurrencyTile extends StatelessWidget {
  const _QuickAddCurrencyTile({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('quick_add_currency_option_$code'),
      title: LtrText(
        data: code,
        style: TextStyle(
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: Color(0xFF2563EB))
          : null,
      onTap: onTap,
    );
  }
}

/// Dialog for entering a custom 3-letter currency code.
Future<String?> showQuickAddOtherCurrencyDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const _QuickAddOtherCurrencyDialog(),
  );
}

class _QuickAddOtherCurrencyDialog extends StatefulWidget {
  const _QuickAddOtherCurrencyDialog();

  @override
  State<_QuickAddOtherCurrencyDialog> createState() =>
      _QuickAddOtherCurrencyDialogState();
}

class _QuickAddOtherCurrencyDialogState
    extends State<_QuickAddOtherCurrencyDialog> {
  final _controller = TextEditingController();
  var _showError = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!isValidQuickAddOtherCurrencyCode(_controller.text)) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(
      normalizeQuickAddCurrencyCode(_controller.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isValid = isValidQuickAddOtherCurrencyCode(_controller.text);

    return AlertDialog(
      title: Text(l10n.quickAddOtherCurrencyTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.characters,
        maxLength: 3,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
          TextInputFormatter.withFunction(
            (oldValue, newValue) => newValue.copyWith(
              text: newValue.text.toUpperCase(),
            ),
          ),
        ],
        decoration: InputDecoration(
          hintText: l10n.quickAddOtherCurrencyHint,
          counterText: '',
          errorText: _showError && !isValid
              ? l10n.quickAddOtherCurrencyInvalid
              : null,
        ),
        onChanged: (_) {
          if (_showError) {
            setState(() => _showError = false);
          } else {
            setState(() {});
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.quickAddOtherCurrencyUse),
        ),
      ],
    );
  }
}
