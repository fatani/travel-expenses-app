// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../expenses/presentation/expense_controller.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../trips/domain/trip.dart';
import '../data/sms_parser_service.dart';
import '../domain/sms_parse_result.dart';

class SmsExpenseScreen extends ConsumerStatefulWidget {
  const SmsExpenseScreen({super.key, required this.trip});

  final Trip trip;

  @override
  ConsumerState<SmsExpenseScreen> createState() => _SmsExpenseScreenState();
}

class _SmsExpenseScreenState extends ConsumerState<SmsExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _smsTextController;
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime? _expenseDate;
  SmsParseResult? _parseResult;
  bool _attemptedParse = false;

  @override
  void initState() {
    super.initState();
    _smsTextController = TextEditingController();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _currencyController = TextEditingController(text: widget.trip.baseCurrency);
    _dateController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _smsTextController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isSaving = ref
        .watch(expenseControllerProvider(widget.trip.id))
        .isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.smsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.smsInputLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _smsTextController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: InputDecoration(
                            hintText: l10n.smsInputHint,
                            border: const OutlineInputBorder(),
                          ),
                          validator: _validateSmsText,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _parseSms,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: Text(l10n.smsParseButton),
                        ),
                        if (_attemptedParse) ...[
                          const SizedBox(height: 12),
                          Text(
                            _parseResult?.hasAnyValue == true
                                ? l10n.smsParseDetectedMessage
                                : l10n.smsParseNoResultMessage,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.smsTitleLabel,
                            hintText: l10n.smsTitleHint,
                            helperText: l10n.smsTitleHelper,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormAmountLabel,
                            hintText: l10n.expenseFormAmountHint,
                          ),
                          validator: _validateAmount,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _currencyController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp('[a-zA-Z]'),
                            ),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormCurrencyLabel,
                            helperText: l10n.smsCurrencyFallbackHelper(
                              widget.trip.baseCurrency,
                            ),
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          items: ExpenseOptionLabels.categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    ExpenseOptionLabels.category(
                                      l10n,
                                      category,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormCategoryLabel,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedPaymentMethod,
                          items: ExpenseOptionLabels.paymentMethods
                              .map(
                                (paymentMethod) => DropdownMenuItem<String>(
                                  value: paymentMethod,
                                  child: Text(
                                    ExpenseOptionLabels.paymentMethod(
                                      l10n,
                                      paymentMethod,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormPaymentMethodLabel,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentMethod = value;
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormDateLabel,
                            suffixIcon: const Icon(
                              Icons.calendar_today_rounded,
                            ),
                          ),
                          onTap: _selectDate,
                          validator: _validateDate,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormNoteLabel,
                            hintText: l10n.expenseFormNoteHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isSaving ? null : _saveExpense,
                    child: Text(l10n.smsSaveButton),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _parseSms() {
    final result = ref
        .read(smsParserServiceProvider)
        .parse(_smsTextController.text);

    setState(() {
      _attemptedParse = true;
      _parseResult = result;
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      _currencyController.text =
          (result.currencyCode ?? widget.trip.baseCurrency).toUpperCase();
      if (result.merchant != null && result.merchant!.isNotEmpty) {
        _titleController.text = result.merchant!;
      }
      final suggestedCategory =
          result.suggestedCategory ?? _inferCategoryFallback(result.rawText);
      if (suggestedCategory != null) {
        _selectedCategory = suggestedCategory;
      }
      final suggestedPaymentMethod =
          _inferPaymentMethodFallback(result.rawText);
      if (suggestedPaymentMethod != null) {
        _selectedPaymentMethod = suggestedPaymentMethod;
      }
      if (result.spentAt != null) {
        _expenseDate = DateUtils.dateOnly(result.spentAt!);
        _syncDateField();
      }
    });

    _formKey.currentState?.validate();
  }

  String? _validateSmsText(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.smsTextRequired;
    }

    return null;
  }

  String? _validateRequired(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.commonRequiredField;
    }

    return null;
  }

  String? _validateAmount(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l10n.commonRequiredField;
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return l10n.commonEnterValidNumber;
    }
    if (amount <= 0) {
      return l10n.expenseFormAmountPositive;
    }

    return null;
  }

  String? _validateDropdown(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l10n.commonRequiredField;
    }

    return null;
  }

  String? _validateDate(String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (_expenseDate == null) {
      return l10n.commonRequiredField;
    }

    return null;
  }

  String? _inferCategoryFallback(String rawText) {
    final normalized = SmsParserService.normalizeIncomingText(rawText)
        .toLowerCase();

    if (normalized.contains('starbucks') ||
        normalized.contains('restaurant') ||
        normalized.contains('مطعم')) {
      return 'Food';
    }
    if (normalized.contains('uber') ||
        normalized.contains('taxi') ||
        normalized.contains('metro')) {
      return 'Transport';
    }

    // Keep form usable when parser has no strong category signal.
    return 'Other';
  }

  String? _inferPaymentMethodFallback(String rawText) {
    final normalized = SmsParserService.normalizeIncomingText(rawText)
        .toLowerCase();

    if (normalized.contains('apple pay') ||
        normalized.contains('google pay') ||
        normalized.contains('samsung pay')) {
      return 'Mobile Wallet';
    }
    if (normalized.contains('بطاقة ائتمانية') ||
        normalized.contains('credit card')) {
      return 'Credit Card';
    }
    if (normalized.contains('بطاقة') ||
        normalized.contains('debit')) {
      return 'Debit Card';
    }

    return null;
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(_expenseDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _expenseDate = DateUtils.dateOnly(selectedDate);
      _syncDateField();
    });

    _formKey.currentState?.validate();
  }

  Future<void> _saveExpense() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.trip.id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.smsTripMissingError)));
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory!
        : _titleController.text.trim();
    final currencyCode = _currencyController.text.trim().toUpperCase();

    if (currencyCode != widget.trip.baseCurrency.trim().toUpperCase()) {
      final shouldKeepAsIs = await _confirmCurrencyMismatch(currencyCode);
      if (shouldKeepAsIs != true) {
        return;
      }
    }

    final controller = ref.read(
      expenseControllerProvider(widget.trip.id).notifier,
    );

    try {
      await controller.createExpense(
        title: title,
        amount: double.parse(_amountController.text.trim()),
        currencyCode: currencyCode,
        category: _selectedCategory!,
        spentAt: _expenseDate!,
        paymentMethod: _selectedPaymentMethod!,
        source: 'sms',
        note: _noteController.text,
        rawSmsText: _smsTextController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.smsSaveError('$error'))));
    }
  }

  Future<bool?> _confirmCurrencyMismatch(String expenseCurrency) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.expenseCurrencyMismatchTitle),
          content: Text(
            l10n.expenseCurrencyMismatchMessage(
              expenseCurrency,
              widget.trip.baseCurrency,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.expenseCurrencyMismatchConvertManually),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.expenseCurrencyMismatchKeepAsIs),
            ),
          ],
        );
      },
    );
  }

  void _syncDateField() {
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final formatter = DateFormat('dd MMM yyyy', localeTag);
    _dateController.text = _expenseDate == null
        ? ''
        : formatter.format(_expenseDate!);
  }
}
