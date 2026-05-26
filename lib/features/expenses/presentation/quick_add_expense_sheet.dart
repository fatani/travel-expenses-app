part of 'trip_details_screen.dart';

class _QuickAddSheetResult {
  const _QuickAddSheetResult.moreDetails(_QuickAddDraftPayload value)
    : openMoreDetails = true,
      savedOutcome = null,
      draft = value;

  const _QuickAddSheetResult.saved(ExpenseCreateOutcome value)
    : openMoreDetails = false,
      savedOutcome = value,
      draft = null;

  final bool openMoreDetails;
  final ExpenseCreateOutcome? savedOutcome;
  final _QuickAddDraftPayload? draft;
}

class QuickAddExpenseSheet extends ConsumerStatefulWidget {
  const QuickAddExpenseSheet({
    super.key,
    required this.trip,
    required this.expenses,
  });

  final Trip trip;
  final List<Expense> expenses;

  @override
  ConsumerState<QuickAddExpenseSheet> createState() =>
      _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends ConsumerState<QuickAddExpenseSheet> {
  bool _showRepeatHint = false;
  bool _isSubmitting = false;
  bool _isOpeningMoreDetails = false;
  late String _selectedCurrencyCode;
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _merchantFocusNode = FocusNode();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _merchantController = TextEditingController();
  late final List<String> _recentMerchants;
  final TextInputFormatter _amountFormatter = TextInputFormatter.withFunction((
    oldValue,
    newValue,
  ) {
    final candidate = newValue.text;
    if (candidate.isEmpty) {
      return newValue;
    }

    final isValid = RegExp(r'^\d*\.?\d*$').hasMatch(candidate);
    return isValid ? newValue : oldValue;
  });

  String _selectedCategory = 'Other';
  bool _showValidationError = false;
  bool _userSelectedCategory = false;
  Map<String, String> _amountCategoryMemory = {};
  String _selectedPaymentChipKey = kQuickAddPaymentCash;

  String _prefsLastCategoryKeyForTrip() =>
      'quick_add_last_category_${widget.trip.id}';

  String _prefsAmountMemoryKeyForTrip() =>
      'quick_add_amount_memory_${widget.trip.id}';

  static const List<String> _quickCategories = <String>[
    'Food',
    'Transport',
    'Accommodation',
    'Shopping',
    'Entertainment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _recentMerchants = deriveRecentMerchants(widget.expenses);
    _selectedCurrencyCode = widget.trip.baseCurrency.trim().toUpperCase();
    _userSelectedCategory = false;

    _applyTripPaymentDefault();
    _loadPreferences();
    _amountController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  void _activateRepeatLast() {
    final lastExpense = mostRecentExpense(widget.expenses);
    if (lastExpense == null) {
      return;
    }

    setState(() {
      _applyRepeatFromExpense(lastExpense);
    });
  }

  void _applyRepeatFromExpense(Expense expense) {
    _userSelectedCategory = true;
    final category = expense.category;
    if (category != null && category.isNotEmpty) {
      _selectedCategory = category;
    }
    _selectedPaymentChipKey = quickAddPaymentChipKeyFromExpense(expense);
    _selectedCurrencyCode = expense.currencyCode.trim().toUpperCase();
    _amountController.text = _formatAmountForField(expense.amount);
    _merchantController.text = expense.title.trim();
    _showRepeatHint = true;
  }

  void _applyTripPaymentDefault() {
    final lastExpense = mostRecentExpense(widget.expenses);
    if (lastExpense == null) {
      return;
    }
    _selectedPaymentChipKey = quickAddPaymentChipKeyFromExpense(lastExpense);
  }

  String _formatAmountForField(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    return amount.toString();
  }

  String _amountRangeKey(double amount) {
    if (amount < 20) return '0-20';
    if (amount < 80) return '20-80';
    if (amount < 300) return '80-300';
    return '300+';
  }

  void _applyCategorySuggestion(double amount) {
    if (_userSelectedCategory) return;

    // Priority 2: learned memory
    final range = _amountRangeKey(amount);
    if (_applyAdaptiveMemorySuggestion(range)) {
      return;
    }

    // Priority 3: static fallback heuristic
    _applyHeuristicSuggestion(amount);
  }

  bool _applyAdaptiveMemorySuggestion(String rangeKey) {
    final rememberedCategory = _amountCategoryMemory[rangeKey];
    if (rememberedCategory == null) {
      return false;
    }
    _selectedCategory = rememberedCategory;
    return true;
  }

  void _applyHeuristicSuggestion(double amount) {
    if (amount < 20) {
      _selectedCategory = 'Food';
      return;
    }
    if (amount < 80) {
      _selectedCategory = 'Transport';
      return;
    }
    if (amount < 300) {
      _selectedCategory = 'Shopping';
      return;
    }
    _selectedCategory = 'Accommodation';
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCategory = prefs.getString(_prefsLastCategoryKeyForTrip());
    final memoryData = prefs.getString(_prefsAmountMemoryKeyForTrip());
    if (mounted) {
      setState(() {
        if (lastCategory != null &&
            lastCategory.isNotEmpty &&
            !_userSelectedCategory &&
            _amountController.text.trim().isEmpty) {
          _selectedCategory = lastCategory;
        }
        if (memoryData != null) {
          _amountCategoryMemory = Map<String, String>.from(
            jsonDecode(memoryData) as Map,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _merchantFocusNode.dispose();
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  bool get _canSaveAmount {
    final amount = double.tryParse(_amountController.text.trim());
    return amount != null && amount > 0;
  }

  String _resolvedExpenseTitle() {
    return resolveQuickAddExpenseTitle(
      merchantText: _merchantController.text,
      category: _selectedCategory,
    );
  }

  void _selectRecentMerchant(String merchant) {
    setState(() {
      _merchantController.text = merchant;
      _merchantController.selection = TextSelection.collapsed(
        offset: merchant.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final canSave = _canSaveAmount && !_isSubmitting;
    const amountHint = '0.00';
    final displayCurrency = _selectedCurrencyCode;
    final amountError = _showValidationError ? _validateAmount(l10n) : null;
    const selectedChipColor = Color(0xFF334155);

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (_showRepeatHint) _buildRepeatHintBanner(l10n),
            TextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              cursorColor: const Color(0xFF0F172A),
              textInputAction: TextInputAction.done,
              inputFormatters: [_amountFormatter],
              onSubmitted: (_) => _onAmountSubmitted(),
              onChanged: _onAmountChanged,
              style: TextStyle(
                fontSize: 30,
                fontWeight: RtlTypography.amountWeight(isArabic),
                color: const Color(0xFF0F172A),
                height: RtlTypography.amountLineHeight(isArabic),
              ),
              decoration: InputDecoration(
                hintText: amountHint,
                hintStyle: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade200,
                ),
                errorText: amountError,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
            LtrText(
              data: l10n.quickAddAmountInCurrency(displayCurrency),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: RtlTypography.bodyLineHeight(isArabic),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _merchantController,
              focusNode: _merchantFocusNode,
              textInputAction: TextInputAction.done,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF334155),
                fontWeight: FontWeight.w500,
                height: RtlTypography.bodyLineHeight(isArabic),
              ),
              decoration: InputDecoration(
                hintText: l10n.quickAddMerchantPlaceholder,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCBD5E1),
                  fontWeight: FontWeight.w400,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.blueGrey.shade200),
                ),
              ),
            ),
            if (_recentMerchants.isNotEmpty) ...[
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentMerchants.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final merchant = _recentMerchants[index];
                    return ExcludeFocus(
                      child: ActionChip(
                        label: Text(
                          merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        labelStyle: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF475569),
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: const Color(0xFFF8FAFC),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        onPressed: () => _selectRecentMerchant(merchant),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: _quickCategories.map((category) {
                final isSelected = _selectedCategory == category;
                return ExcludeFocus(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _userSelectedCategory = true;
                        _selectedCategory = category;
                      });
                    },
                    child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isArabic ? 13 : 12,
                      vertical: isArabic ? 9 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedChipColor
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ExpenseOptionLabels.category(l10n, category),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontWeight: RtlTypography.chipWeight(isArabic),
                        height: RtlTypography.chipLineHeight(isArabic),
                      ),
                    ),
                  ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 6),
            _buildPaymentRow(l10n),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: canSave ? _save : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: const Color(0xFF2563EB),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.tripDetailsQuickAddSave,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
            TextButton(
              onPressed: _isSubmitting || _isOpeningMoreDetails
                  ? null
                  : _openMoreDetails,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 4),
              ),
              child: Text(
                l10n.quickAddAddDetails,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (widget.expenses.isNotEmpty && !_showRepeatHint)
              TextButton(
                onPressed: _activateRepeatLast,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(top: 0, bottom: 4),
                ),
                child: Text(
                  l10n.tripDetailsRepeatLastExpense,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onAmountChanged(String value) {
    setState(() {
      final parsed = double.tryParse(value);
      if (parsed != null) {
        _applyCategorySuggestion(parsed);
      }
    });
  }

  Widget _buildPaymentRow(AppLocalizations l10n) {
    final isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final options = <({String key, String label})>[
      (key: kQuickAddPaymentCash, label: l10n.paymentMethodCash),
      (key: kQuickAddPaymentCard, label: l10n.tripDetailsQuickAddPaymentCard),
      (key: kQuickAddPaymentOther, label: l10n.paymentMethodOther),
    ];

    return Row(
      children: options.map((option) {
        final isSelected = _selectedPaymentChipKey == option.key;
        return Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: Semantics(
              button: true,
              selected: isSelected,
              label: option.label,
              child: SizedBox(
                height: 34,
                child: ExcludeFocus(
                  child: ChoiceChip(
                    selected: isSelected,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      option.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? const Color(0xFF334155)
                            : const Color(0xFF64748B),
                        fontWeight: isSelected
                            ? RtlTypography.chipWeight(isArabic)
                            : FontWeight.w500,
                        height: RtlTypography.chipLineHeight(isArabic),
                      ),
                    ),
                    backgroundColor: const Color(0xFFF8FAFC),
                    selectedColor: const Color(0xFFE2E8F0),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFFE2E8F0),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedPaymentChipKey = option.key;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRepeatHintBanner(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        l10n.tripDetailsRepeatHint,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String? _validateAmount(AppLocalizations l10n) {
    final value = _amountController.text.trim();
    if (value.isEmpty) {
      return l10n.commonRequiredField;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return l10n.commonEnterValidNumber;
    }
    if (parsed <= 0) {
      return l10n.expenseFormAmountPositive;
    }
    return null;
  }

  void _onAmountSubmitted() {
    if (!_canSaveAmount) {
      setState(() {
        _showValidationError = true;
      });
      return;
    }
    _save();
  }

  Future<void> _save() async {
    if (_isSubmitting) {
      return;
    }
    await _saveWithPayment(_selectedQuickPayment());
  }

  Future<void> _saveWithPayment(_QuickAddPaymentData payment) async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _showValidationError = true;
    });

    final amountError = _validateAmount(l10n);
    if (amountError != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();

    final amount = double.parse(_amountController.text.trim());
    final now = DateTime.now();
    final isCashQuickExpense = isCashExpensePayment(
      paymentMethod: payment.method,
      paymentChannel: payment.channel,
    );

    var didPop = false;
    try {
      final outcome = await ref
          .read(expenseControllerProvider(widget.trip.id).notifier)
          .createExpense(
            title: _resolvedExpenseTitle(),
            amount: amount,
            currencyCode: _selectedCurrencyCode,
            category: _selectedCategory,
            spentAt: now,
            paymentMethod: payment.method,
            paymentNetwork: isCashQuickExpense ? null : payment.network,
            paymentChannel: payment.channel,
            cardProfileId: payment.cardProfileId,
            tripHomeCurrency: widget.trip.homeCurrencySnapshot,
          );

      if (!mounted) {
        return;
      }

      await _savePreferences(amount);

      if (!mounted) {
        return;
      }

      didPop = true;
      Navigator.of(context).pop(_QuickAddSheetResult.saved(outcome));
    } catch (_) {
      if (!mounted) {
        return;
      }

      CalmSnackBar.showMessage(
        context,
        message: l10n.expenseFormSaveFailed,
      );
    } finally {
      if (!didPop && mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _openMoreDetails() {
    if (_isSubmitting || _isOpeningMoreDetails) {
      return;
    }
    _isOpeningMoreDetails = true;
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(_savePreferences());
    Navigator.of(context).pop(
      _QuickAddSheetResult.moreDetails(
        _QuickAddDraftPayload(
          title: _resolvedExpenseTitle(),
          amountText: _amountController.text,
          category: _selectedCategory,
          paymentMethod:
              quickAddPaymentMethodForAddDetails(_selectedPaymentChipKey),
          currencyCode: _selectedCurrencyCode,
          spentAt: DateTime.now(),
        ),
      ),
    );
  }

  _QuickAddPaymentData _selectedQuickPayment() {
    final payload = quickAddPaymentPayloadForChip(_selectedPaymentChipKey);
    return _QuickAddPaymentData(
      method: payload.method,
      network: payload.network,
      channel: payload.channel ?? '',
      cardProfileId: payload.cardProfileId,
    );
  }

  Future<void> _savePreferences([double? amount]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastCategoryKeyForTrip(), _selectedCategory);
    if (amount != null) {
      final range = _amountRangeKey(amount);
      _amountCategoryMemory[range] = _selectedCategory;
      await prefs.setString(
        _prefsAmountMemoryKeyForTrip(),
        jsonEncode(_amountCategoryMemory),
      );
    }
  }
}

class _QuickAddPaymentData {
  const _QuickAddPaymentData({
    required this.method,
    required this.network,
    required this.channel,
    required this.cardProfileId,
  });

  final String method;
  final String network;
  final String channel;
  final int? cardProfileId;
}

class _QuickAddDraftPayload {
  const _QuickAddDraftPayload({
    required this.title,
    required this.amountText,
    required this.category,
    required this.paymentMethod,
    required this.currencyCode,
    required this.spentAt,
  });

  final String title;
  final String amountText;
  final String category;
  final String paymentMethod;
  final String currencyCode;
  final DateTime spentAt;
}
