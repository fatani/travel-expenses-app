import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/design_system/app_surfaces.dart';
import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/formatting/bidi_format.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/domain/expense_payment_service.dart';
import '../../reports/data/trip_cash_balances_provider.dart';
import '../../reports/data/trip_report_provider.dart';
import '../../trips/domain/trip.dart';
import '../domain/over_refund_exception.dart';
import '../domain/refund_destination.dart';
import 'linked_refund_home_snapshot.dart';
import 'trip_refunds_provider.dart';

class RefundFormScreen extends ConsumerStatefulWidget {
  const RefundFormScreen({
    super.key,
    required this.trip,
    required this.expense,
  });

  final Trip trip;
  final Expense expense;

  @override
  ConsumerState<RefundFormScreen> createState() => _RefundFormScreenState();
}

class _RefundFormScreenState extends ConsumerState<RefundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late RefundDestination _destination;
  bool _isSubmitting = false;

  bool get _isCashExpense => isCashExpensePayment(
        paymentMethod: widget.expense.paymentMethod,
        paymentChannel: widget.expense.paymentChannel,
      );

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _destination = _isCashExpense
        ? RefundDestination.cash
        : RefundDestination.card;
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = widget.expense.transactionCurrency.trim().toUpperCase();
    final parsedAmount = double.tryParse(_amountController.text.trim());
    String? homeValueHint;
    if (parsedAmount != null && parsedAmount > 0) {
      final snapshot = linkedRefundHomeSnapshot(
        expense: widget.expense,
        refundAmount: parsedAmount,
      );
      final homeAmount = snapshot.homeAmount;
      final homeCurrency = snapshot.homeCurrency;
      if (homeAmount != null && homeCurrency != null) {
        homeValueHint = l10n.refundFormHomeValueHint(
          BidiAmountFormat.formatWithCurrency(homeAmount, homeCurrency),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.refundFormTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.expense.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    LtrText(
                      data: BidiAmountFormat.formatWithCurrency(
                        widget.expense.transactionAmount,
                        currency,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.refundFormAmountLabel,
                  hintText: l10n.expenseFormAmountHint,
                  suffixText: currency,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return l10n.refundFormAmountPositive;
                  }
                  return null;
                },
              ),
              if (homeValueHint != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  homeValueHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (!_isCashExpense) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<RefundDestination>(
                  initialValue: _destination,
                  decoration: InputDecoration(
                    labelText: l10n.refundFormDestinationLabel,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: RefundDestination.card,
                      child: Text(l10n.refundFormDestinationCard),
                    ),
                    DropdownMenuItem(
                      value: RefundDestination.cash,
                      child: Text(l10n.refundFormDestinationCash),
                    ),
                  ],
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _destination = value;
                          });
                        },
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: l10n.refundFormNoteLabel,
                  hintText: l10n.refundFormNoteHint,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.refundFormSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final l10n = AppLocalizations.of(context)!;
    final amount = double.parse(_amountController.text.trim());
    final currency = widget.expense.transactionCurrency.trim().toUpperCase();
    final homeSnapshot = linkedRefundHomeSnapshot(
      expense: widget.expense,
      refundAmount: amount,
    );

    try {
      await ref.read(recordRefundUseCaseProvider).execute(
            destination: _isCashExpense ? RefundDestination.cash : _destination,
            tripId: widget.trip.id,
            expenseId: widget.expense.id,
            refundAmount: amount,
            refundCurrency: currency,
            homeAmount: homeSnapshot.homeAmount,
            homeCurrency: homeSnapshot.homeCurrency,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            linkedExpense: widget.expense,
          );

      ref.invalidate(tripRefundsProvider(widget.trip.id));
      ref.invalidate(tripReportProvider(widget.trip.id));
      ref.invalidate(tripCashBalancesProvider(widget.trip.id));

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on OverRefundException {
      if (mounted) {
        CalmSnackBar.showMessage(
          context,
          message: l10n.refundFormOverRefundError,
        );
      }
    } catch (_) {
      if (mounted) {
        CalmSnackBar.showMessage(
          context,
          message: l10n.refundFormSaveFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
