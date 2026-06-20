import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/design_system/calm_snackbar.dart';
import '../../../core/formatting/bidi_format.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import '../../expenses/domain/expense.dart';
import '../../trips/domain/trip.dart';
import '../domain/allowed_refund_currencies.dart';
import '../domain/over_refund_exception.dart';
import '../domain/refund_destination.dart';
import 'linked_refund_home_snapshot.dart';
import 'trip_refunds_provider.dart';

/// Trip-level refund entry point.
///
/// Unlike [RefundFormScreen], this screen is not tied to a single expense. It
/// supports recording a refund directly from the trip screen — cash or card,
/// linked to an existing expense or unlinked.
///
/// Home-currency valuation:
/// * When a linked expense is chosen, the home snapshot is inherited from that
///   expense (same path used by the per-expense refund form).
/// * When unlinked and the refund currency equals the trip's home currency, the
///   refund is valued 1:1 in home currency so it reduces net spending.
/// * Otherwise no home value is derived (existing app behaviour — rates are
///   never invented).  Unlinked cash refunds in a non-home currency are blocked
///   because the cash-lot basis cannot be established without a home value.
class TripRefundFormScreen extends ConsumerStatefulWidget {
  const TripRefundFormScreen({
    super.key,
    required this.trip,
    this.expenses = const [],
  });

  final Trip trip;
  final List<Expense> expenses;

  @override
  ConsumerState<TripRefundFormScreen> createState() =>
      _TripRefundFormScreenState();
}

class _TripRefundFormScreenState extends ConsumerState<TripRefundFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final List<String> _allowedCurrencies;
  late String _currency;
  RefundDestination _destination = RefundDestination.card;
  String? _linkedExpenseId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    _allowedCurrencies = buildAllowedRefundCurrencies(
      homeCurrency: widget.trip.homeCurrencySnapshot,
      destinationCurrency: widget.trip.destinationCurrency,
      expenses: widget.expenses,
    );
    // Default to the trip destination currency; it is always present in the
    // allowed list. Fall back to the first allowed code if destination is blank.
    final defaultCurrency = widget.trip.destinationCurrency.trim().toUpperCase();
    _currency = defaultCurrency.isNotEmpty
        ? defaultCurrency
        : (_allowedCurrencies.isNotEmpty
            ? _allowedCurrencies.first
            : widget.trip.homeCurrencySnapshot.trim().toUpperCase());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Expense? get _linkedExpense {
    final id = _linkedExpenseId;
    if (id == null) return null;
    for (final expense in widget.expenses) {
      if (expense.id == id) return expense;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currency = _currency;
    // The dropdown must always be able to render the active selection. A linked
    // expense can settle in a currency that is not otherwise an allowed refund
    // currency, so union it in to avoid an invalid-value assertion.
    final currencyOptions = <String>[
      ..._allowedCurrencies,
      if (currency.isNotEmpty && !_allowedCurrencies.contains(currency))
        currency,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.refundFormTripTitle),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              DropdownButtonFormField<RefundDestination>(
                initialValue: _destination,
                decoration: InputDecoration(
                  labelText: l10n.refundFormTypeLabel,
                ),
                items: [
                  DropdownMenuItem(
                    value: RefundDestination.card,
                    child: Text(l10n.refundFormTypeCard),
                  ),
                  DropdownMenuItem(
                    value: RefundDestination.cash,
                    child: Text(l10n.refundFormTypeCash),
                  ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _destination = value);
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: l10n.refundFormAmountLabel,
                  hintText: l10n.expenseFormAmountHint,
                  suffixText: currency.isEmpty ? null : currency,
                ),
                validator: (value) {
                  final parsed = double.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return l10n.refundFormAmountPositive;
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: currency.isEmpty ? null : currency,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.refundFormCurrencyLabel,
                ),
                items: [
                  for (final code in currencyOptions)
                    DropdownMenuItem<String>(
                      value: code,
                      child: LtrText(data: code),
                    ),
                ],
                onChanged: (_isSubmitting || _linkedExpenseId != null)
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _currency = value);
                      },
              ),
              if (widget.expenses.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String?>(
                  initialValue: _linkedExpenseId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.refundFormLinkLabel,
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(l10n.refundFormLinkNone),
                    ),
                    for (final expense in widget.expenses)
                      DropdownMenuItem<String?>(
                        value: expense.id,
                        child: Text(
                          _expenseLabel(expense),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _isSubmitting ? null : _onLinkedExpenseChanged,
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

  String _expenseLabel(Expense expense) {
    final amount = BidiAmountFormat.formatWithCurrency(
      expense.transactionAmount,
      expense.transactionCurrency.trim().toUpperCase(),
    );
    return '${expense.title} · $amount';
  }

  void _onLinkedExpenseChanged(String? value) {
    setState(() {
      _linkedExpenseId = value;
      final expense = _linkedExpense;
      if (expense != null) {
        // Linked refunds always settle in the original expense currency.
        _currency = expense.transactionCurrency.trim().toUpperCase();
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final amount = double.parse(_amountController.text.trim());
    final currency = _currency.trim().toUpperCase();
    final linkedExpense = _linkedExpense;
    final homeCurrency = widget.trip.homeCurrencySnapshot.trim().toUpperCase();

    // Derive the home snapshot.
    double? homeAmount;
    String? homeCurrencyCode;
    if (linkedExpense != null) {
      final snapshot = linkedRefundHomeSnapshot(
        expense: linkedExpense,
        refundAmount: amount,
      );
      homeAmount = snapshot.homeAmount;
      homeCurrencyCode = snapshot.homeCurrency;
    } else if (homeCurrency.isNotEmpty && currency == homeCurrency) {
      // Refund is in the home currency — value it 1:1 so reports update.
      homeAmount = amount;
      homeCurrencyCode = homeCurrency;
    }

    // Unlinked cash refunds need a home value to set the cash-lot basis.
    if (_destination == RefundDestination.cash &&
        linkedExpense == null &&
        homeAmount == null) {
      CalmSnackBar.showMessage(
        context,
        message: l10n.refundFormUnlinkedCashNeedsHome,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref.read(recordRefundUseCaseProvider).execute(
            destination: _destination,
            tripId: widget.trip.id,
            expenseId: linkedExpense?.id,
            refundAmount: amount,
            refundCurrency: currency,
            homeAmount: homeAmount,
            homeCurrency: homeCurrencyCode,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
            linkedExpense: linkedExpense,
          );

      ref.invalidate(tripRefundsProvider(widget.trip.id));

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
