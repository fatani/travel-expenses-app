import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/design_system/app_surfaces.dart';
import '../../trips/domain/trip.dart';
import '../domain/expense.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/theme/design_tokens.dart';
import 'expense_controller.dart';
import 'expense_option_labels.dart';
import '../../settings/presentation/cards_provider.dart';
import '../../settings/domain/card_display_helper.dart';
import '../../settings/presentation/add_card_screen.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.trip,
    this.expense,
    this.initialAmount,
    this.initialCategory,
    this.initialPaymentMethod,
    this.initialCurrency,
    this.initialSpentAt,
  });

  final Trip trip;
  final Expense? expense;
  final String? initialAmount;
  final String? initialCategory;
  final String? initialPaymentMethod;
  final String? initialCurrency;
  final DateTime? initialSpentAt;

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
  late final TextEditingController _timeController;
  late final TextEditingController _noteController;
  late final TextEditingController _chargedHomeAmountController;

  String? _selectedCategory;
  String? _selectedPaymentNetwork;
  String? _selectedPaymentChannel;
  int? _selectedCardProfileId;
  int? _preferredCardProfileId;
  DateTime? _spentAt;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    final initialPayment = _mapInitialPaymentMethod(widget.initialPaymentMethod);
    _titleController = TextEditingController(text: expense?.title ?? '');
    _amountController = TextEditingController(
      text: expense == null
          ? (widget.initialAmount?.trim() ?? '')
          : expense.amount.toStringAsFixed(2),
    );
    _currencyController = TextEditingController(
      text:
          expense?.currencyCode ?? widget.initialCurrency ?? widget.trip.baseCurrency,
    );
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _noteController = TextEditingController(text: expense?.note ?? '');
    final homeCurrency = widget.trip.homeCurrencySnapshot.trim().toUpperCase();
    final seededChargedHomeAmount =
      (expense?.totalChargedAmount != null &&
        (expense?.totalChargedCurrency ?? '').trim().toUpperCase() ==
          homeCurrency)
      ? expense!.totalChargedAmount!.toStringAsFixed(2)
      : '';
    _chargedHomeAmountController = TextEditingController(
      text: seededChargedHomeAmount,
    );
    _selectedCategory = expense?.category ?? widget.initialCategory;
    _selectedPaymentNetwork = expense?.paymentNetwork?.isNotEmpty == true
      ? expense!.paymentNetwork
      : expense != null
        ? 'Other'
        : initialPayment?.network;
    _selectedPaymentChannel = expense?.paymentChannel?.isNotEmpty == true
      ? expense!.paymentChannel
      : expense != null
        ? 'Other'
        : initialPayment?.channel;
    _spentAt = expense?.spentAt ?? widget.initialSpentAt ?? DateTime.now();
    _selectedCardProfileId = expense?.cardProfileId;
    _syncDateAndTimeFields(useLocale: false);

    if (!widget.isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _initLastUsedCard(),
      );
    }
  }

  /// Queries the last card used in this trip and auto-selects it if it still
  /// exists. Falls through silently on any error.
  Future<void> _initLastUsedCard() async {
    if (!mounted) return;

    try {
      final lastCardId = await ref
          .read(expenseRepositoryProvider)
          .getLastCardExpenseCardId(widget.trip.id);
      if (!mounted || lastCardId == null) return;

      setState(() {
        _preferredCardProfileId = lastCardId;
      });
    } catch (_) {
      // Keep the form lightweight even when repository access is unavailable
      // (for example in unit/widget tests without a real database).
    }
  }

  _InitialPaymentSelection? _mapInitialPaymentMethod(String? value) {
    switch (value) {
      case 'Cash':
        return const _InitialPaymentSelection(network: 'Other', channel: 'Cash');
      case 'Wallet':
        return const _InitialPaymentSelection(
          network: 'Other',
          channel: 'Mobile Wallet',
        );
      case 'Card':
        return const _InitialPaymentSelection(
          network: 'Visa',
          channel: 'POS Purchase',
        );
      default:
        return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDateAndTimeFields();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _noteController.dispose();
    _chargedHomeAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isSaving = ref
        .watch(expenseControllerProvider(widget.trip.id))
        .isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEditMode
              ? l10n.expenseFormEditTitle
              : l10n.expenseFormCreateTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidationErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  backgroundColor: Colors.white.withValues(alpha: 0.82),
                  borderColor: AppColors.borderSoft.withValues(alpha: 0.45),
                  radius: AppRadius.lg,
                  shadows: AppShadows.card,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        _SectionLabel(
                          title: isArabic ? 'البيانات الأساسية' : 'Basic expense',
                        ),
                        TextFormField(
                          controller: _titleController,
                          textInputAction: TextInputAction.next,
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: l10n.expenseFormTitleLabel,
                            hintText: l10n.expenseFormTitleHint,
                            helperText: l10n.expenseFormTitleHelper,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: _requiredLabel(l10n.expenseFormAmountLabel),
                            hintText: l10n.expenseFormAmountHint,
                          ),
                          validator: _validateAmount,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _currencyController,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: _requiredLabel(l10n.expenseFormCurrencyLabel),
                            hintText: 'USD',
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 18),
                        _SectionLabel(
                          title: isArabic ? 'التصنيف' : 'Classification',
                        ),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedCategory,
                          items: ExpenseOptionLabels.categories
                              .map(
                                (category) => DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(
                                    ExpenseOptionLabels.category(l10n, category),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: _requiredLabel(l10n.expenseFormCategoryLabel),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value;
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _selectedPaymentChannel,
                          items: ExpenseOptionLabels.paymentChannels
                              .map(
                                (paymentChannel) => DropdownMenuItem<String>(
                                  value: paymentChannel,
                                  child: Text(
                                    ExpenseOptionLabels.paymentChannel(
                                      l10n,
                                      paymentChannel,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: _requiredLabel(
                              l10n.expenseFormPaymentChannelLabel,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentChannel = value;
                              if (!_isCardPaymentChannel(value)) {
                                _selectedCardProfileId = null;
                              }
                            });
                          },
                          validator: _validateDropdown,
                        ),
                        _CardDropdown(
                          selectedCardProfileId: _selectedCardProfileId,
                          preferredCardProfileId: _preferredCardProfileId,
                          isCardPayment: _isCardPayment,
                          onChanged: (id) {
                            setState(() {
                              _selectedCardProfileId = id;
                            });
                          },
                        ),
                        if (_isCardPayment) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _chargedHomeAmountController,
                            textInputAction: TextInputAction.next,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _premiumInputDecoration(
                              context,
                              labelText: l10n.expenseFormChargedAmountLabel(
                                widget.trip.homeCurrencySnapshot
                                    .trim()
                                    .toUpperCase(),
                              ),
                              hintText: l10n.expenseFormAmountHint,
                              helperText: l10n.expenseFormChargedAmountHelper,
                            ),
                            validator: _validateOptionalAmount,
                          ),
                        ],
                        const SizedBox(height: 18),
                        _SectionLabel(
                          title: isArabic ? 'التاريخ والملاحظات' : 'Date & Notes',
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _dateController,
                                readOnly: true,
                                decoration: _premiumInputDecoration(
                                  context,
                                  labelText: _requiredLabel(l10n.expenseFormDateLabel),
                                  suffixIcon: const Icon(Icons.calendar_today_rounded),
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
                                decoration: _premiumInputDecoration(
                                  context,
                                  labelText: _requiredLabel(l10n.expenseFormTimeLabel),
                                  suffixIcon: const Icon(Icons.access_time_rounded),
                                ),
                                onTap: _selectTime,
                                validator: _validateDate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: _premiumInputDecoration(
                            context,
                            labelText: l10n.expenseFormNoteLabel,
                            hintText: l10n.expenseFormNoteHint,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: Opacity(
                    opacity: isSaving ? 0.65 : 1,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: isSaving ? null : _submit,
                        child: Ink(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.isEditMode
                                  ? (isArabic ? 'حفظ التغييرات' : 'Save changes')
                                  : l10n.expenseFormSaveCreate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
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

  InputDecoration _premiumInputDecoration(
    BuildContext context, {
    required String labelText,
    String? hintText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    const fillColor = Color(0xFFF1F5F9);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
          width: 1.2,
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
      _spentAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        _spentAt?.hour ?? 0,
        _spentAt?.minute ?? 0,
      );
      _syncDateAndTimeFields();
    });

    if (_showValidationErrors) {
      _formKey.currentState?.validate();
    }
  }

  Future<void> _selectTime() async {
    final initialDate = _spentAt ?? DateTime.now();
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      final baseDate = _spentAt ?? DateTime.now();
      _spentAt = DateTime(
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

  Future<void> _submit() async {
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
    final amount = double.parse(_amountController.text.trim());
    final currencyCode = _currencyController.text.trim().toUpperCase();
    final chargedHomeAmountRaw = _chargedHomeAmountController.text.trim();
    final chargedHomeAmount = chargedHomeAmountRaw.isEmpty
      ? null
      : double.tryParse(chargedHomeAmountRaw);
    final normalizedHomeCurrency =
      widget.trip.homeCurrencySnapshot.trim().toUpperCase();
    final paymentChannel = _selectedPaymentChannel!;
    final derivedCardNetwork = _deriveNetworkFromSelectedCard();
    final paymentNetwork = _isCashChannel(paymentChannel)
      ? null
      : (derivedCardNetwork ?? _selectedPaymentNetwork);
    final paymentMethod = _resolvePaymentMethodCompatibility(
      paymentNetwork,
      paymentChannel,
    );

    if (_isCardPayment && chargedHomeAmountRaw.isNotEmpty) {
      if (chargedHomeAmount == null || chargedHomeAmount <= 0) {
        return;
      }
    }

    if (widget.expense == null &&
        currencyCode != widget.trip.baseCurrency.trim().toUpperCase()) {
      final shouldKeepAsIs = await _confirmCurrencyMismatch(currencyCode);
      if (shouldKeepAsIs != true) {
        return;
      }
    }

    final controller = ref.read(
      expenseControllerProvider(widget.trip.id).notifier,
    );

    try {
      if (widget.expense == null) {
        final outcome = await controller.createExpense(
          title: title,
          amount: amount,
          currencyCode: currencyCode,
          category: _selectedCategory!,
          spentAt: _spentAt!,
          paymentMethod: paymentMethod,
          paymentNetwork: paymentNetwork,
          paymentChannel: paymentChannel,
            totalChargedAmount: _isCardPayment ? chargedHomeAmount : null,
            totalChargedCurrency:
              _isCardPayment && chargedHomeAmount != null
              ? normalizedHomeCurrency
              : null,
          note: _noteController.text,
          cardProfileId: _selectedCardProfileId,
          tripHomeCurrency: widget.trip.homeCurrencySnapshot,
        );

        if (!mounted) {
          return;
        }

        Navigator.of(context).pop(outcome);
        return;
      } else {
        await controller.updateExpense(
          expense: widget.expense!,
          title: title,
          amount: amount,
          currencyCode: currencyCode,
          category: _selectedCategory!,
          spentAt: _spentAt!,
          paymentMethod: paymentMethod,
          paymentNetwork: paymentNetwork,
          paymentChannel: paymentChannel,
            totalChargedAmount: _isCardPayment ? chargedHomeAmount : null,
            totalChargedCurrency:
              _isCardPayment && chargedHomeAmount != null
              ? normalizedHomeCurrency
              : null,
          note: _noteController.text,
          cardProfileId: _selectedCardProfileId,
          tripHomeCurrency: widget.trip.homeCurrencySnapshot,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(null);
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

  String _resolvePaymentMethodCompatibility(String? network, String channel) {
    if (channel == 'Cash') {
      return 'Cash';
    }
    if (channel == 'Mobile Wallet') {
      return 'Mobile Wallet';
    }
    if (network == null || network.isEmpty) {
      return 'Other';
    }
    if (network == 'Mada') {
      return 'Debit Card';
    }
    if (network == 'Visa' || network == 'Mastercard') {
      return 'Credit Card';
    }
    if (channel == 'POS Purchase' || channel == 'Online Purchase') {
      return 'Other';
    }
    return 'Other';
  }

  void _syncDateAndTimeFields({bool useLocale = true}) {
    if (_spentAt == null) {
      _dateController.text = '';
      _timeController.text = '';
      return;
    }

    final localeTag = useLocale
        ? Localizations.localeOf(context).toLanguageTag()
        : null;
    _dateController.text = DateFormat('dd MMM yyyy', localeTag).format(_spentAt!);
    _timeController.text = DateFormat('HH:mm', localeTag).format(_spentAt!);
  }

  String _requiredLabel(String label) {
    return '$label *';
  }

  bool get _isCardPayment => _isCardPaymentChannel(_selectedPaymentChannel);

  bool _isCardPaymentChannel(String? channel) =>
      channel == 'POS Purchase' || channel == 'Online Purchase';

  bool _isCashChannel(String? channel) => channel == 'Cash';

  String? _validateOptionalAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed == null) {
      return AppLocalizations.of(context)!.commonEnterValidNumber;
    }
    if (parsed <= 0) {
      return AppLocalizations.of(context)!.expenseFormAmountPositive;
    }
    return null;
  }

  String? _deriveNetworkFromSelectedCard() {
    final selectedCardId = _selectedCardProfileId;
    if (selectedCardId == null || !_isCardPayment) {
      return null;
    }

    final cards = ref.read(cardsProvider).valueOrNull;
    if (cards == null || cards.isEmpty) {
      return null;
    }

    dynamic matchedCard;
    for (final card in cards) {
      if (card.id == selectedCardId) {
        matchedCard = card;
        break;
      }
    }

    if (matchedCard == null) {
      return null;
    }

    final customNetwork = matchedCard.customCardNetwork?.trim();
    if (customNetwork != null && customNetwork.isNotEmpty) {
      return customNetwork;
    }

    final network = matchedCard.cardNetwork?.trim();
    if (network == null || network.isEmpty) {
      return null;
    }

    return network;
  }
}

class _InitialPaymentSelection {
  const _InitialPaymentSelection({required this.network, required this.channel});

  final String network;
  final String channel;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w800,
          letterSpacing: 0.15,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Renders a card dropdown only when [isCardPayment] is true and cards exist.
/// Auto-selects the card when there is exactly one card available.
class _CardDropdown extends ConsumerStatefulWidget {
  const _CardDropdown({
    required this.selectedCardProfileId,
    required this.preferredCardProfileId,
    required this.onChanged,
    required this.isCardPayment,
  });

  final int? selectedCardProfileId;
  final int? preferredCardProfileId;
  final ValueChanged<int?> onChanged;
  final bool isCardPayment;

  @override
  ConsumerState<_CardDropdown> createState() => _CardDropdownState();
}

class _CardDropdownState extends ConsumerState<_CardDropdown> {
  bool _didAutoSelect = false;

  @override
  void didUpdateWidget(_CardDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset so we can auto-select again if user switches back to card payment.
    if (!oldWidget.isCardPayment && widget.isCardPayment) {
      _didAutoSelect = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCardPayment) return const SizedBox.shrink();

    final cardsAsync = ref.watch(cardsProvider);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final label = isArabic ? 'البطاقة' : 'Card';
    final noneLabel = isArabic ? 'بدون بطاقة' : 'No card';

    return cardsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => const SizedBox.shrink(),
      data: (cards) {
        if (cards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: const Color(0xFF64748B),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AddCardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                label: Text(
                  isArabic ? '+ إضافة بطاقة (اختياري)' : '+ Add card (optional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }

        final hasExplicitSelection = widget.selectedCardProfileId != null;
        final preferredCardId = widget.preferredCardProfileId;
        final hasPreferredCard = preferredCardId != null &&
            cards.any((card) => card.id == preferredCardId);

        // Auto-select preferred/last-used card when available, otherwise fallback
        // to single-card auto-select.
        if (!_didAutoSelect &&
            !hasExplicitSelection &&
            (hasPreferredCard || cards.length == 1)) {
          final autoSelectedCardId = hasPreferredCard
              ? preferredCardId
              : cards.first.id;
          _didAutoSelect = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onChanged(autoSelectedCardId);
          });
        }

        return Column(
          children: [
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              isExpanded: true,
              key: ValueKey(widget.selectedCardProfileId),
              initialValue: widget.selectedCardProfileId,
              selectedItemBuilder: (context) {
                final selectedLabels = <String>[
                  noneLabel,
                  ...cards.map(
                    (card) => CardDisplayHelper.getDisplayStringWithIcon(
                      context,
                      card,
                    ),
                  ),
                ];
                return selectedLabels
                    .map(
                      (labelText) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          labelText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList();
              },
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    noneLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ...cards.map(
                  (card) => DropdownMenuItem<int?>(
                    value: card.id,
                    child: Text(
                      CardDisplayHelper.getDisplayStringWithIcon(context, card),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              decoration: InputDecoration(
                labelText: label,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    width: 1.4,
                  ),
                ),
              ),
              onChanged: widget.onChanged,
            ),
          ],
        );
      },
    );
  }
}
