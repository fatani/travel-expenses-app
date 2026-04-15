// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

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
  late final TextEditingController _timeController;
  late final TextEditingController _noteController;

  String? _selectedCategory;
  String? _selectedPaymentNetwork;
  String? _selectedPaymentChannel;
  DateTime? _expenseDate;
  SmsParseResult? _parseResult;
  bool _attemptedParse = false;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _smsTextController = TextEditingController();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _currencyController = TextEditingController(text: widget.trip.baseCurrency);
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _smsTextController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _dateController.dispose();
    _timeController.dispose();
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
            autovalidateMode: _showValidationErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
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
                          _requiredLabel(l10n.smsInputLabel),
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
                          if (_hasFinancialBreakdown(_parseResult)) ...[
                            const SizedBox(height: 12),
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.intlBreakdownTitle,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    if (_parseResult?.billedAmount != null)
                                      _BreakdownRow(
                                        label: l10n.intlBilled,
                                        value: _formatMoney(
                                          _parseResult!.billedAmount!,
                                          _parseResult!.billedCurrency,
                                        ),
                                      ),
                                    if (_parseResult?.feesAmount != null)
                                      _BreakdownRow(
                                        label: l10n.intlFees,
                                        value: _formatMoney(
                                          _parseResult!.feesAmount!,
                                          _parseResult!.feesCurrency,
                                        ),
                                        subtle: true,
                                      ),
                                    if (_parseResult?.totalChargedAmount !=
                                        null)
                                      _BreakdownRow(
                                        label: l10n.intlTotalCharged,
                                        value: _formatMoney(
                                          _parseResult!.totalChargedAmount!,
                                          _parseResult!.totalChargedCurrency,
                                        ),
                                        bold: true,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
                            labelText: _requiredLabel(
                              l10n.expenseFormAmountLabel,
                            ),
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
                            labelText: _requiredLabel(
                              l10n.expenseFormCurrencyLabel,
                            ),
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
                            labelText: _requiredLabel(
                              l10n.expenseFormCategoryLabel,
                            ),
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
                          value: _selectedPaymentNetwork,
                          items: ExpenseOptionLabels.paymentNetworks
                              .map(
                                (paymentNetwork) => DropdownMenuItem<String>(
                                  value: paymentNetwork,
                                  child: Text(
                                    ExpenseOptionLabels.paymentNetwork(
                                      l10n,
                                      paymentNetwork,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: _requiredLabel(
                              l10n.expenseFormPaymentNetworkLabel,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentNetwork = value;
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedPaymentChannel,
                          items: ExpenseOptionLabels.paymentChannels
                              .map(
                                (paymentChannel) => DropdownMenuItem<String>(
                                  value: paymentChannel,
                                  child: Text(
                                    ExpenseOptionLabels.paymentChannel(
                                      l10n,
                                      paymentChannel,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: InputDecoration(
                            labelText: _requiredLabel(
                              l10n.expenseFormPaymentChannelLabel,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentChannel = value;
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: _requiredLabel(
                                    l10n.expenseFormDateLabel,
                                  ),
                                  suffixIcon: const Icon(
                                    Icons.calendar_today_rounded,
                                  ),
                                ),
                                onTap: _selectDate,
                                validator: _validateDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _timeController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: l10n.expenseFormTimeLabel,
                                  suffixIcon: const Icon(
                                    Icons.access_time_rounded,
                                  ),
                                ),
                                onTap: _selectTime,
                              ),
                            ),
                          ],
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
      final suggestedPaymentNetwork =
          result.suggestedPaymentNetwork ?? _inferPaymentNetworkFallback(result.rawText);
      if (suggestedPaymentNetwork != null) {
        _selectedPaymentNetwork = suggestedPaymentNetwork;
      }
      final suggestedPaymentChannel =
          result.suggestedPaymentChannel ?? _inferPaymentChannelFallback(result.rawText);
      final safePaymentChannel = _normalizePaymentChannelForDropdown(
        suggestedPaymentChannel,
      );
      if (safePaymentChannel != null) {
        _selectedPaymentChannel = safePaymentChannel;
      }
      if (result.spentAt != null) {
        _expenseDate = result.spentAt!;
        _syncDateAndTimeFields();
      }
    });

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

  String? _inferPaymentNetworkFallback(String rawText) {
    final normalized = SmsParserService.normalizeIncomingText(rawText)
        .toLowerCase();

    if (normalized.contains('mastercard')) {
      return 'Mastercard';
    }
    if (normalized.contains('فيزا') || normalized.contains('visa')) {
      return 'Visa';
    }
    if (normalized.contains('مدى') || normalized.contains('mada')) {
      return 'Mada';
    }

    return null;
  }

  String? _inferPaymentChannelFallback(String rawText) {
    final normalized = SmsParserService.normalizeIncomingText(rawText)
        .toLowerCase();

    if (normalized.contains('شراء إنترنت') ||
        normalized.contains('شراء انترنت') ||
        normalized.contains('online') ||
        normalized.contains('internet')) {
      return 'Online Purchase';
    }
    if (normalized.contains('شراء عبر نقاط البيع') ||
        normalized.contains('pos')) {
      return 'POS Purchase';
    }

    return null;
  }

  String? _normalizePaymentChannelForDropdown(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (ExpenseOptionLabels.paymentChannels.contains(value)) {
      return value;
    }

    if (value == 'POS International Purchase') {
      return 'POS Purchase';
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
      _expenseDate = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _expenseDate?.hour ?? 0,
        _expenseDate?.minute ?? 0,
      );
      _syncDateAndTimeFields();
    });

    if (_showValidationErrors) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _selectTime() async {
    final initialDate = _expenseDate ?? DateTime.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      final baseDate = _expenseDate ?? DateTime.now();
      _expenseDate = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
      _syncDateAndTimeFields();
    });

    if (_showValidationErrors) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _saveExpense() async {
    final l10n = AppLocalizations.of(context)!;
    if (widget.trip.id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.smsTripMissingError)));
      return;
    }

    if (!_showValidationErrors) {
      setState(() {
        _showValidationErrors = true;
      });
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory!
        : _titleController.text.trim();
    final transactionAmount = double.parse(_amountController.text.trim());
    final currencyCode = _currencyController.text.trim().toUpperCase();
    final paymentMethod = _resolvePaymentMethodCompatibility(
      _selectedPaymentNetwork!,
      _selectedPaymentChannel!,
    );
    final parsed = _parseResult;

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
        amount: transactionAmount,
        currencyCode: currencyCode,
        transactionAmount: transactionAmount,
        transactionCurrency: currencyCode,
        billedAmount: parsed?.billedAmount,
        billedCurrency: parsed?.billedCurrency,
        feesAmount: parsed?.feesAmount,
        feesCurrency: parsed?.feesCurrency,
        totalChargedAmount: parsed?.totalChargedAmount,
        totalChargedCurrency: parsed?.totalChargedCurrency,
        isInternational:
            currencyCode.toUpperCase() != 'SAR' ||
            ((parsed?.feesAmount ?? 0) > 0),
        category: _selectedCategory!,
        spentAt: _expenseDate!,
        paymentMethod: paymentMethod,
        paymentNetwork: _selectedPaymentNetwork!,
        paymentChannel: _selectedPaymentChannel!,
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

  String _resolvePaymentMethodCompatibility(String network, String channel) {
    if (network == 'Mada') {
      return 'Debit Card';
    }
    if (network == 'Visa' || network == 'Mastercard') {
      return 'Credit Card';
    }
    return 'Other';
  }

  void _syncDateAndTimeFields() {
    if (_expenseDate == null) {
      _dateController.text = '';
      _timeController.text = '';
      return;
    }
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    _dateController.text = DateFormat('dd MMM yyyy', localeTag).format(
      _expenseDate!,
    );
    _timeController.text = DateFormat('HH:mm', localeTag).format(_expenseDate!);
  }

  String _requiredLabel(String label) {
    return '$label *';
  }

  bool _hasFinancialBreakdown(SmsParseResult? result) {
    if (result == null) {
      return false;
    }

    return result.billedAmount != null ||
        result.feesAmount != null ||
        result.totalChargedAmount != null;
  }

  String _formatMoney(double amount, String? currency) {
    final normalizedCurrency = (currency == null || currency.trim().isEmpty)
        ? widget.trip.baseCurrency
        : currency.trim().toUpperCase();
    final formatter = NumberFormat.currency(
      name: normalizedCurrency,
      symbol: '$normalizedCurrency ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.subtle = false,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool subtle;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final color = subtle
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : null;
    final style = bold
        ? baseStyle?.copyWith(fontWeight: FontWeight.bold, color: color)
        : baseStyle?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Directionality(
        textDirection: ui.TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: style),
            Text(value, style: style),
          ],
        ),
      ),
    );
  }
}
