// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import '../../../core/providers/database_providers.dart';
import '../../expenses/presentation/expense_controller.dart';
import '../../expenses/presentation/expense_option_labels.dart';
import '../../settings/domain/card_display_helper.dart';
import '../../settings/presentation/add_card_screen.dart';
import '../../settings/presentation/cards_provider.dart';
import '../../trips/domain/trip.dart';
import '../data/sms_parser_service.dart';
import '../domain/sms_parse_result.dart';
import '../domain/sms_parse_result_money_mapper.dart';

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
  int? _selectedCardProfileId;
  int? _preferredCardProfileId;
  DateTime? _expenseDate;
  SmsParseResult? _parseResult;
  bool _attemptedParse = false;
  bool _showValidationErrors = false;
  bool _isApplyingParsedCurrency = false;
  bool _didUserEditCurrency = false;

  @override
  void initState() {
    super.initState();
    _smsTextController = TextEditingController();
    _titleController = TextEditingController();
    _amountController = TextEditingController();
    _currencyController = TextEditingController(text: widget.trip.baseCurrency);
    _currencyController.addListener(_onCurrencyChangedByUser);
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _noteController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLastUsedCard();
    });
  }

  /// Queries the last card used in this trip and marks it as preferred.
  /// Falls through silently on any error to keep this form lightweight.
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
      // Keep form usable in environments without repository/db access.
    }
  }

  @override
  void dispose() {
    _smsTextController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _currencyController.removeListener(_onCurrencyChangedByUser);
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.smsScreenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            autovalidateMode: _showValidationErrors
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context, isArabic),
                const SizedBox(height: 24),
                _buildSmsInputCard(context, l10n),
                const SizedBox(height: 20),
                if (_attemptedParse) ...[
                  Text(
                    _parseResult?.hasAnyValue == true
                        ? l10n.smsParseDetectedMessage
                        : l10n.smsParseNoResultMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_hasFinancialBreakdown(_parseResult))
                    _buildFinancialBreakdownCard(context, l10n),
                  const SizedBox(height: 20),
                ],
                _buildExpenseDetailsCard(context, l10n),
                const SizedBox(height: 24),
                _buildSaveButton(context, l10n, isSaving),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, bool isArabic) {
    return Column(
      crossAxisAlignment: isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.message_rounded,
              color: Color(0xFF7C3AED),
              size: 36,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            isArabic ? 'أضف رسالة البنك' : 'Add bank message',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            isArabic
                ? 'الصق الرسالة وسنملأ البيانات تلقائيًا'
                : 'Paste the message and we\'ll fill the details automatically',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSmsInputCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.08),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _requiredLabel(l10n.smsInputLabel),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _smsTextController,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: l10n.smsInputHint,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: _validateSmsText,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _parseSms,
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${AppLocalizations.of(context)!.smsParseButton} ✨',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildFinancialBreakdownCard(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.05),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.intlBreakdownTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
              ),
              const SizedBox(height: 12),
              if (_parseResult?.billedAmount != null)
                _BreakdownRow(
                  label: l10n.intlBilled,
                  value: _formatMoney(
                    _parseResult!.billedAmount!,
                    _parseResult!.billedCurrency,
                  ),
                ),
              if (_parseResult?.feesAmount != null) ...[
                const SizedBox(height: 8),
                _BreakdownRow(
                  label: l10n.intlFees,
                  value: _formatMoney(
                    _parseResult!.feesAmount!,
                    _parseResult!.feesCurrency,
                  ),
                  subtle: true,
                ),
              ],
              if (_parseResult?.totalChargedAmount != null) ...[
                const SizedBox(height: 10),
                _BreakdownRow(
                  label: l10n.intlTotalCharged,
                  value: _formatMoney(
                    _parseResult!.totalChargedAmount!,
                    _parseResult!.totalChargedCurrency,
                  ),
                  bold: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseDetailsCard(BuildContext context, AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.06),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                  labelText: l10n.smsTitleLabel,
                  hintText: l10n.smsTitleHint,
                  helperText: l10n.smsTitleHelper,
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
                  FilteringTextInputFormatter.allow(
                    RegExp('[a-zA-Z]'),
                  ),
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: _premiumInputDecoration(
                  context,
                  labelText: _requiredLabel(l10n.expenseFormCurrencyLabel),
                  helperText: l10n.smsCurrencyFallbackHelper(
                    widget.trip.baseCurrency,
                  ),
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
                          ExpenseOptionLabels.category(
                            l10n,
                            category,
                          ),
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
                  labelText: _requiredLabel(l10n.expenseFormPaymentChannelLabel),
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
              _SmsCardDropdown(
                selectedCardProfileId: _selectedCardProfileId,
                preferredCardProfileId: _preferredCardProfileId,
                isCardPayment: _isCardPayment,
                onChanged: (id) {
                  setState(() {
                    _selectedCardProfileId = id;
                  });
                },
              ),
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
                      decoration: _premiumInputDecoration(
                        context,
                        labelText: _requiredLabel(l10n.expenseFormTimeLabel),
                        suffixIcon: const Icon(
                          Icons.access_time_rounded,
                        ),
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
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, AppLocalizations l10n, bool isSaving) {
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: isSaving ? 0.65 : 1.0,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: isSaving ? null : _saveExpense,
            child: Ink(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  l10n.smsSaveButton,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
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
      _isApplyingParsedCurrency = true;
      _currencyController.text =
          (result.currencyCode ?? widget.trip.baseCurrency).toUpperCase();
      _isApplyingParsedCurrency = false;
      _didUserEditCurrency = false;
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

  void _onCurrencyChangedByUser() {
    if (_isApplyingParsedCurrency) {
      return;
    }
    _didUserEditCurrency = true;
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

    if (value == 'Apple Pay' ||
        value == 'Google Pay' ||
        value == 'شراء عبر نقاط البيع') {
      return 'POS Purchase';
    }

    if (value == 'Ecommerce' || value == 'شراء عبر الإنترنت') {
      return 'Online Purchase';
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
    final paymentChannel = _selectedPaymentChannel!;
    final derivedCardNetwork = _deriveNetworkFromSelectedCard();
    final inferredNetworkFromRawText = _inferPaymentNetworkFallback(
      _smsTextController.text,
    );
    final paymentNetwork = _isCashChannel(paymentChannel)
        ? null
        : (derivedCardNetwork ??
              _selectedPaymentNetwork ??
              inferredNetworkFromRawText);
    final paymentMethod = _resolvePaymentMethodCompatibility(
      paymentNetwork,
      paymentChannel,
    );
    final parsed = _parseResult;
    final parsedMoney = parsed?.toMoneyModel();
    final baseCurrency = widget.trip.baseCurrency.trim().toUpperCase();
    final billedMatchesBaseCurrency =
        parsed?.billedCurrency?.trim().toUpperCase() == baseCurrency;
    final shouldWarnCurrencyMismatch =
        _didUserEditCurrency &&
        currencyCode != baseCurrency &&
        !billedMatchesBaseCurrency;

    if (shouldWarnCurrencyMismatch) {
      final shouldKeepAsIs = await _confirmCurrencyMismatch(currencyCode);
      if (shouldKeepAsIs != true) {
        return;
      }
    }

    final controller = ref.read(
      expenseControllerProvider(widget.trip.id).notifier,
    );

    try {
      final outcome = await controller.createExpense(
        title: title,
        amount: transactionAmount,
        currencyCode: currencyCode,
        moneyModel: parsedMoney?.copyWith(
          transactionAmount: transactionAmount,
          transactionCurrency: currencyCode,
          isInternational: currencyCode.toUpperCase() != 'SAR' ||
              parsedMoney.isInternational,
        ),
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
            (parsed?.feesAmount != null),
        category: _selectedCategory!,
        spentAt: _expenseDate!,
        paymentMethod: paymentMethod,
        paymentNetwork: paymentNetwork,
        paymentChannel: paymentChannel,
        cardProfileId: _selectedCardProfileId,
        source: 'sms',
        note: _noteController.text,
        rawSmsText: _smsTextController.text.trim(),
        tripHomeCurrency: widget.trip.homeCurrencySnapshot,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(outcome);
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

  bool get _isCardPayment => _isCardPaymentChannel(_selectedPaymentChannel);

  bool _isCardPaymentChannel(String? channel) =>
      channel == 'POS Purchase' || channel == 'Online Purchase';

  bool _isCashChannel(String? channel) => channel == 'Cash';

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
        ? baseStyle?.copyWith(
            fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF0F172A),
          )
        : baseStyle?.copyWith(color: color);
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
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

class _SmsCardDropdown extends ConsumerStatefulWidget {
  const _SmsCardDropdown({
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
  ConsumerState<_SmsCardDropdown> createState() => _SmsCardDropdownState();
}

class _SmsCardDropdownState extends ConsumerState<_SmsCardDropdown> {
  bool _didAutoSelect = false;

  @override
  void didUpdateWidget(_SmsCardDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
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
                labelText: '$label (${isArabic ? 'اختياري' : 'optional'})',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    width: 1.2,
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
