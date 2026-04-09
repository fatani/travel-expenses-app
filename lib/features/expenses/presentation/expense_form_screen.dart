import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import 'expense_controller.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.trip, this.expense});

  final Trip trip;
  final Expense? expense;

  bool get isEditMode => expense != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
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
    'Cash',
    'Credit Card',
    'Debit Card',
    'Bank Transfer',
    'Mobile Wallet',
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _dateController;
  late final TextEditingController _noteController;

  String? _selectedCategory;
  String? _selectedPaymentMethod;
  DateTime? _spentAt;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _titleController = TextEditingController(text: expense?.title ?? '');
    _amountController = TextEditingController(
      text: expense == null ? '' : expense.amount.toStringAsFixed(2),
    );
    _currencyController = TextEditingController(
      text: expense?.currencyCode ?? widget.trip.baseCurrency,
    );
    _dateController = TextEditingController();
    _noteController = TextEditingController(text: expense?.note ?? '');
    _selectedCategory = expense?.category;
    _selectedPaymentMethod = expense?.paymentMethod.isNotEmpty == true
        ? expense!.paymentMethod
        : null;
    _spentAt = expense?.spentAt;
    _syncDateField();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      appBar: AppBar(
        title: Text(widget.isEditMode ? 'Edit Expense' : 'New Expense'),
      ),
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
                      children: [
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Airport taxi',
                            helperText:
                                'Optional. If empty, category will be used.',
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
                            hintText: '45.00',
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
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            hintText: 'USD',
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
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            hintText: 'Optional details',
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
                    onPressed: isSaving ? null : _submit,
                    child: Text(
                      widget.isEditMode ? 'Save Changes' : 'Create Expense',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final initialDate = _spentAt ?? DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialDate),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final title = _titleController.text.trim().isEmpty
        ? _selectedCategory!
        : _titleController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final controller = ref.read(
      expenseControllerProvider(widget.trip.id).notifier,
    );

    try {
      if (widget.expense == null) {
        await controller.createExpense(
          title: title,
          amount: amount,
          currencyCode: _currencyController.text.trim().toUpperCase(),
          category: _selectedCategory!,
          spentAt: _spentAt!,
          paymentMethod: _selectedPaymentMethod!,
          note: _noteController.text,
        );
      } else {
        await controller.updateExpense(
          expense: widget.expense!,
          title: title,
          amount: amount,
          currencyCode: _currencyController.text.trim().toUpperCase(),
          category: _selectedCategory!,
          spentAt: _spentAt!,
          paymentMethod: _selectedPaymentMethod!,
          note: _noteController.text,
        );
      }

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
      ).showSnackBar(SnackBar(content: Text('Failed to save expense: $error')));
    }
  }

  void _syncDateField() {
    final formatter = DateFormat('dd MMM yyyy');
    _dateController.text = _spentAt == null ? '' : formatter.format(_spentAt!);
  }
}
