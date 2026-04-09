import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../expenses/presentation/expense_controller.dart';
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
  static const List<String> _categories = <String>[
    'Transport',
    'Accommodation',
    'Food',
    'Visa',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  static const List<String> _paymentMethods = <String>[
    'Credit Card',
    'Debit Card',
    'Cash',
    'Bank Transfer',
    'Mobile Wallet',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _smsController;
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  DateTime? _spentAt;
  String? _selectedCategory;
  String? _selectedPaymentMethod;
  SmsParseResult? _parseResult;
  bool _hasAttemptedParse = false;

  @override
  void initState() {
    super.initState();
    _smsController = TextEditingController();
    _merchantController = TextEditingController();
    _amountController = TextEditingController();
    _currencyController = TextEditingController(text: widget.trip.baseCurrency);
    _dateController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _smsController.dispose();
    _merchantController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref
        .watch(expenseControllerProvider(widget.trip.id))
        .isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Add via Bank SMS')),
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
                          'Paste bank SMS',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _smsController,
                          minLines: 5,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            hintText:
                                'Paste the bank notification here to extract amount, merchant, date, and category.',
                            border: OutlineInputBorder(),
                          ),
                          validator: _validateSms,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _parseSms,
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Parse SMS'),
                        ),
                        if (_hasAttemptedParse) ...[
                          const SizedBox(height: 12),
                          Text(
                            _parseResult?.hasAnyParsedValue == true
                                ? 'Parsed values loaded below. Review and edit before saving.'
                                : 'No reliable fields detected. Complete the form manually.',
                            style: Theme.of(context).textTheme.bodySmall,
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
                          controller: _merchantController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Merchant or description',
                            hintText: 'Starbucks Airport',
                            helperText:
                                'Optional. If empty, selected category will be used as the title.',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            hintText: '52.40',
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
                            labelText: 'Currency',
                            helperText:
                                'Falls back to ${widget.trip.baseCurrency} if the SMS does not include one.',
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Category',
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
                          initialValue: _selectedPaymentMethod,
                          items: _paymentMethods
                              .map(
                                (paymentMethod) => DropdownMenuItem<String>(
                                  value: paymentMethod,
                                  child: Text(paymentMethod),
                                ),
                              )
                              .toList(),
                          decoration: const InputDecoration(
                            labelText: 'Payment method',
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
                          decoration: const InputDecoration(
                            labelText: 'Expense date',
                            suffixIcon: Icon(Icons.calendar_today_rounded),
                          ),
                          onTap: _selectDate,
                          validator: _validateDate,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _noteController,
                          minLines: 2,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            hintText: 'Optional note',
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
                    child: const Text('Save Expense'),
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
    final rawText = _smsController.text.trim();
    final result = ref.read(smsParserServiceProvider).parse(rawText);

    setState(() {
      _hasAttemptedParse = true;
      _parseResult = result;
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      _currencyController.text =
          (result.currencyCode ?? widget.trip.baseCurrency).toUpperCase();
      if ((result.merchant ?? '').isNotEmpty) {
        _merchantController.text = result.merchant!;
      }
      if ((result.suggestedCategory ?? '').isNotEmpty) {
        _selectedCategory = result.suggestedCategory;
      }
      if (result.spentAt != null) {
        _spentAt = DateUtils.dateOnly(result.spentAt!);
        _syncDateField();
      }
    });

    _formKey.currentState?.validate();
  }

  String? _validateSms(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Paste the SMS text first.';
    }

    return null;
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Enter a valid number.';
    }
    if (amount <= 0) {
      return 'Amount must be greater than zero.';
    }

    return null;
  }

  String? _validateDropdown(String? value) {
    if (value == null || value.isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _validateDate(String? value) {
    if (_spentAt == null) {
      return 'This field is required.';
    }

    return null;
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(_spentAt ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _spentAt = DateUtils.dateOnly(selectedDate);
      _syncDateField();
    });

    _formKey.currentState?.validate();
  }

  Future<void> _saveExpense() async {
    if (widget.trip.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip is missing. Reopen this screen.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _merchantController.text.trim().isEmpty
        ? _selectedCategory!
        : _merchantController.text.trim();
    final controller = ref.read(
      expenseControllerProvider(widget.trip.id).notifier,
    );

    try {
      await controller.createExpense(
        title: title,
        amount: double.parse(_amountController.text.trim()),
        currencyCode: _currencyController.text.trim().toUpperCase(),
        category: _selectedCategory!,
        spentAt: _spentAt!,
        paymentMethod: _selectedPaymentMethod!,
        source: 'sms',
        note: _noteController.text,
        rawSmsText: _smsController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save SMS expense: $error')),
      );
    }
  }

  void _syncDateField() {
    final formatter = DateFormat('dd MMM yyyy');
    _dateController.text = _spentAt == null ? '' : formatter.format(_spentAt!);
  }
}
