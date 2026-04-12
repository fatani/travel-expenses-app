import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import 'expense_controller.dart';
import 'expense_option_labels.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key, required this.trip, this.expense});

  final Trip trip;
  final Expense? expense;

  bool get isEditMode => expense != null;

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
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
    final l10n = AppLocalizations.of(context)!;
    final isSaving = ref
        .watch(expenseControllerProvider(widget.trip.id))
        .isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? l10n.expenseFormEditTitle
              : l10n.expenseFormCreateTitle,
        ),
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
                          decoration: InputDecoration(
                            labelText: l10n.expenseFormTitleLabel,
                            hintText: l10n.expenseFormTitleHint,
                            helperText: l10n.expenseFormTitleHelper,
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
                            hintText: 'USD',
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
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
                          initialValue: _selectedPaymentMethod,
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
                          minLines: 3,
                          maxLines: 5,
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
                    onPressed: isSaving ? null : _submit,
                    child: Text(
                      widget.isEditMode
                          ? l10n.expenseFormSaveEdit
                          : l10n.expenseFormSaveCreate,
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
    if (_spentAt == null) {
      return l10n.commonRequiredField;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.expenseFormSaveError('$error'),
          ),
        ),
      );
    }
  }

  void _syncDateField() {
    final formatter = DateFormat('dd MMM yyyy');
    _dateController.text = _spentAt == null ? '' : formatter.format(_spentAt!);
  }
}
