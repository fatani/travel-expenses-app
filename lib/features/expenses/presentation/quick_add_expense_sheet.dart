part of 'trip_details_screen.dart';

class _QuickAddSheetResult {
  const _QuickAddSheetResult.moreDetails(_QuickAddDraftPayload value)
    : openMoreDetails = true,
      addAnother = false,
      repeatCategory = null,
      repeatPaymentChipKey = null,
      payload = null,
      draft = value;

  const _QuickAddSheetResult.submit(_QuickAddSubmitPayload value)
    : openMoreDetails = false,
      addAnother = false,
      repeatCategory = null,
      repeatPaymentChipKey = null,
      payload = value,
      draft = null;

  const _QuickAddSheetResult.submitAndAddAnother(
    _QuickAddSubmitPayload value, {
    required String category,
    required String paymentChipKey,
  }) : openMoreDetails = false,
       addAnother = true,
       repeatCategory = category,
       repeatPaymentChipKey = paymentChipKey,
       payload = value,
       draft = null;

  final bool openMoreDetails;
  final bool addAnother;
  final String? repeatCategory;
  final String? repeatPaymentChipKey;
  final _QuickAddSubmitPayload? payload;
  final _QuickAddDraftPayload? draft;
}

class QuickAddExpenseSheet extends ConsumerStatefulWidget {
  const QuickAddExpenseSheet({
    super.key,
    required this.trip,
    required this.expenses,
    this.repeatLast = false,
    this.lastExpense,
    this.repeatCategory,
    this.repeatPaymentChipKey,
  });

  final Trip trip;
  final List<Expense> expenses;
  final bool repeatLast;
  final Expense? lastExpense;
  final String? repeatCategory;
  final String? repeatPaymentChipKey;

  @override
  ConsumerState<QuickAddExpenseSheet> createState() =>
      _QuickAddExpenseSheetState();
}

class _QuickAddExpenseSheetState extends ConsumerState<QuickAddExpenseSheet> {
  bool _showRepeatHint = false;
  final TextEditingController _amountController = TextEditingController();
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
  String? _animatingCategory;
  bool _showValidationError = false;
  bool _userSelectedCategory = false;
  bool _isPrefilledFromMemory = false;
  double? _lastAmountSuggestion;
  Map<String, String> _amountCategoryMemory = {};
  int? _lastUsedCardProfileId;
  String _selectedPaymentChipKey = 'cash';

  static const String _prefsLastAmountKey = 'last_amount';
  static const String _prefsLastCategoryKey = 'last_category';
  static const String _prefsAmountMemoryKey = 'amount_memory';

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
    _userSelectedCategory = false;
    _lastUsedCardProfileId = _resolveLastUsedCardProfileId();
    if (_lastUsedCardProfileId != null) {
      _selectedPaymentChipKey = _paymentChipKeyForCard(_lastUsedCardProfileId!);
    }
    // Repeat Last / Add Another logic
    if (widget.repeatLast) {
      final category = widget.repeatCategory ?? widget.lastExpense?.category;
      final paymentKey = widget.repeatPaymentChipKey ??
          (widget.lastExpense != null ? _paymentChipKeyForExpense(widget.lastExpense!) : null);
      if (category != null) {
        _selectedCategory = category;
        _userSelectedCategory = true;
      }
      if (paymentKey != null) {
        _selectedPaymentChipKey = paymentKey;
      }
      _lastUsedCardProfileId = widget.lastExpense?.cardProfileId;
      _amountController.text = '';
      _showRepeatHint = true;
      _isPrefilledFromMemory = false;
    } else {
      _loadPreferences();
    }
  }

  String _paymentChipKeyForExpense(Expense e) {
    if (e.cardProfileId != null) {
      return _paymentChipKeyForCard(e.cardProfileId!);
    }
    return e.paymentMethod;
  }

  int? _resolveLastUsedCardProfileId() {
    for (final expense in widget.expenses) {
      if (expense.cardProfileId == null) {
        continue;
      }
      if (!isCardExpenseChannel(expense.paymentChannel)) {
        continue;
      }
      return expense.cardProfileId;
    }
    return null;
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
    final lastAmount = prefs.getDouble(_prefsLastAmountKey);
    final lastCategory = prefs.getString(_prefsLastCategoryKey);
    final memoryData = prefs.getString(_prefsAmountMemoryKey);
    if (mounted) {
      setState(() {
        if (lastAmount != null) {
          _lastAmountSuggestion = lastAmount;
          _selectedCategory = lastCategory ?? 'Other';
          _isPrefilledFromMemory = true;
        } else {
          _lastAmountSuggestion = null;
          _selectedCategory = lastCategory ?? 'Other';
          _isPrefilledFromMemory = false;
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
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cardsState = ref.watch(cardsProvider);
    final cards = cardsState.valueOrNull ?? const <CardProfile>[];
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardOpen = keyboardInset > 0;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.42;
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    final canSave = amount != null && amount > 0;
    final amountHint = _lastAmountSuggestion != null
      ? _lastAmountSuggestion!.toStringAsFixed(2)
      : '0.00';
    final paymentOptions = _buildPaymentOptions(cards);

    final amountError = _showValidationError ? _validateAmount(l10n) : null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: isKeyboardOpen
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 10),
            if (_showRepeatHint)
              _buildRepeatHintBanner(l10n, paymentOptions),
            TextField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              cursorColor: const Color(0xFF0F172A),
              textInputAction: TextInputAction.done,
              inputFormatters: [_amountFormatter],
              onSubmitted: (_) => _save(),
              onChanged: (value) {
                setState(() {
                  _isPrefilledFromMemory = false;
                  final amount = double.tryParse(value);
                  if (amount != null) {
                    _applyCategorySuggestion(amount);
                  }
                });
              },
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: _isPrefilledFromMemory
                    ? const Color(0xFF64748B)
                    : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: amountHint,
                hintStyle: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.blueGrey.shade200,
                ),
                errorText: amountError,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: _quickCategories.map((category) {
                final isSelected = _selectedCategory == category;
                final isAnimating = _animatingCategory == category;
                final selectedColor = _showRepeatHint
                    ? const Color(0xFF6D28D9)
                    : (_isPrefilledFromMemory && !_userSelectedCategory
                        ? const Color(0xFFA78BFA)
                        : const Color(0xFF7C3AED));
                return AnimatedScale(
                  scale: isAnimating ? 0.95 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPrefilledFromMemory = false;
                        _userSelectedCategory = true;
                        _selectedCategory = category;
                        _animatingCategory = category;
                      });
                      Future<void>.delayed(const Duration(milliseconds: 120), () {
                        if (!mounted) {
                          return;
                        }
                        setState(() {
                          if (_animatingCategory == category) {
                            _animatingCategory = null;
                          }
                        });
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected && _showRepeatHint
                            ? Border.all(color: const Color(0xFF5B21B6), width: 1.5)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: selectedColor.withValues(
                                    alpha: _showRepeatHint ? 0.35 : 0.25,
                                  ),
                                  blurRadius: _showRepeatHint ? 12 : 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        ExpenseOptionLabels.category(l10n, category),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
                builder: (context, constraints) {
                  final maxCards = constraints.maxWidth < 380 ? 2 : 3;
                  final cashOption = paymentOptions.firstWhere(
                    (option) => option.key == 'cash',
                    orElse: () => paymentOptions.first,
                  );
                  final cardOptions = paymentOptions
                      .where((option) => option.key != 'cash')
                      .toList(growable: false)
                    ..sort((a, b) {
                      final rankA = a.label.startsWith('Visa')
                          ? 0
                          : (a.label.startsWith('MC') ? 1 : 2);
                      final rankB = b.label.startsWith('Visa')
                          ? 0
                          : (b.label.startsWith('MC') ? 1 : 2);
                      if (rankA != rankB) {
                        return rankA.compareTo(rankB);
                      }
                      return a.label.compareTo(b.label);
                    });
                  final visibleOptions = <_QuickAddPaymentOption>[cashOption];
                  for (final option in cardOptions) {
                    if (visibleOptions.length - 1 >= maxCards) {
                      break;
                    }
                    visibleOptions.add(option);
                  }

                  return Row(
                    children: [
                      ...visibleOptions.map((option) {
                        final isSelected = _selectedPaymentChipKey == option.key;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 6),
                            child: SizedBox(
                              height: 32,
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
                                    color: isSelected
                                        ? (_showRepeatHint
                                            ? const Color(0xFF1E293B)
                                            : const Color(0xFF334155))
                                        : const Color(0xFF64748B),
                                    fontWeight: isSelected && _showRepeatHint
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: const Color(0xFFF8FAFC),
                                selectedColor: _showRepeatHint && isSelected
                                    ? const Color(0xFFE0E7FF)
                                    : const Color(0xFFEFF3F7),
                                side: BorderSide(
                                  color: isSelected
                                      ? (_showRepeatHint
                                          ? const Color(0xFF475569)
                                          : const Color(0xFF94A3B8))
                                      : const Color(0xFFE2E8F0),
                                  width: isSelected && _showRepeatHint ? 1.5 : 1,
                                ),
                                onSelected: (_) {
                                  setState(() {
                                    _selectedPaymentChipKey = option.key;
                                  });
                                },
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(
                        height: 32,
                        child: ActionChip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          label: const Text('...'),
                          onPressed: _openMoreDetails,
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Opacity(
                    opacity: canSave ? 1.0 : 0.65,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: canSave ? _save : null,
                        child: Ink(
                          height: 58,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                const SizedBox(width: 9),
                                Text(
                                  AppLocalizations.of(context)!.quickAddQuickSave,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
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
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openMoreDetails,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(l10n.quickAddAddDetails),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRepeatHintBanner(
    AppLocalizations l10n,
    List<_QuickAddPaymentOption> paymentOptions,
  ) {
    final categoryLabel = ExpenseOptionLabels.category(l10n, _selectedCategory);
    var paymentLabel = l10n.paymentMethodCash;
    for (final option in paymentOptions) {
      if (option.key == _selectedPaymentChipKey) {
        paymentLabel = option.label;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Text(
            l10n.tripDetailsRepeatHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7C3AED),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          _RepeatRestoredLine(label: categoryLabel),
          const SizedBox(height: 2),
          _RepeatRestoredLine(label: paymentLabel),
        ],
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

  void _save() {
    _saveWithPayment(_selectedQuickPayment());
  }

  void _saveWithPayment(_QuickAddPaymentData payment, {bool addAnother = false}) {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _showValidationError = true;
    });

    final amountError = _validateAmount(l10n);
    if (amountError != null) {
      return;
    }

    final amount = double.parse(_amountController.text.trim());
    final now = DateTime.now();

    // Save category memory for next time
    _savePreferences(amount);

    final submitPayload = _QuickAddSubmitPayload(
      title: _selectedCategory,
      amount: amount,
      currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
      category: _selectedCategory,
      spentAt: now,
      payment: payment,
    );

    Navigator.of(context).pop(
      addAnother
          ? _QuickAddSheetResult.submitAndAddAnother(
              submitPayload,
              category: _selectedCategory,
              paymentChipKey: _selectedPaymentChipKey,
            )
          : _QuickAddSheetResult.submit(submitPayload),
    );
  }

  void _openMoreDetails() {
    final selectedPayment = _selectedQuickPayment();
    _savePreferences();
    Navigator.of(context).pop(
      _QuickAddSheetResult.moreDetails(
        _QuickAddDraftPayload(
          title: _selectedCategory,
          amountText: _amountController.text,
          category: _selectedCategory,
          paymentMethod: selectedPayment.method,
          currencyCode: widget.trip.baseCurrency.trim().toUpperCase(),
          spentAt: DateTime.now(),
        ),
      ),
    );
  }

  List<_QuickAddPaymentOption> _buildPaymentOptions(List<CardProfile> cards) {
    final cardsById = <int, CardProfile>{for (final card in cards) card.id: card};
    final options = <_QuickAddPaymentOption>[
      _QuickAddPaymentOption(
        key: 'cash',
        label: AppLocalizations.of(context)!.paymentMethodCash,
        payment: _defaultQuickPayment,
      ),
    ];

    final seenCardIds = <int>{};
    for (final expense in widget.expenses) {
      final cardId = expense.cardProfileId;
      if (cardId == null || seenCardIds.contains(cardId)) {
        continue;
      }
      if (!isCardExpenseChannel(expense.paymentChannel)) {
        continue;
      }

      final card = cardsById[cardId];
      if (card == null) {
        continue;
      }

      options.add(
        _QuickAddPaymentOption(
          key: _paymentChipKeyForCard(cardId),
          label: _cardChipLabel(card, expense.paymentNetwork),
          payment: _paymentForCard(card, expense),
        ),
      );
      seenCardIds.add(cardId);
      if (seenCardIds.length >= 3) {
        break;
      }
    }

    if (options.length == 1 && cards.isNotEmpty) {
      final fallbackCard = _lastUsedCardProfileId == null
          ? cards.first
          : cards.firstWhere(
              (card) => card.id == _lastUsedCardProfileId,
              orElse: () => cards.first,
            );
      options.add(
        _QuickAddPaymentOption(
          key: _paymentChipKeyForCard(fallbackCard.id),
          label: _cardChipLabel(fallbackCard, fallbackCard.cardNetwork),
          payment: _paymentForCardFallback(fallbackCard),
        ),
      );
    }

    return options;
  }

  _QuickAddPaymentData _paymentForCardFallback(CardProfile card) {
    final network =
        _normalizedText(card.cardNetwork ?? card.customCardNetwork) ?? 'Other';
    const channel = 'POS Purchase';
    return _QuickAddPaymentData(
      method: resolvePaymentMethodHint(network, channel),
      network: network,
      channel: channel,
      cardProfileId: card.id,
    );
  }

  _QuickAddPaymentData _selectedQuickPayment() {
    final cards = ref.read(cardsProvider).valueOrNull ?? const <CardProfile>[];
    final options = _buildPaymentOptions(cards);
    for (final option in options) {
      if (option.key == _selectedPaymentChipKey) {
        return option.payment;
      }
    }
    return _defaultQuickPayment;
  }

  String _paymentChipKeyForCard(int cardId) => 'card:$cardId';

  String _cardChipLabel(CardProfile card, String? fallbackNetwork) {
    final network = _normalizedText(
          fallbackNetwork ?? card.cardNetwork ?? card.customCardNetwork,
        ) ??
        'Card';
    final compactNetwork = _compactNetworkLabel(network);
    final last4 = _normalizedText(card.last4);
    if (last4 != null) {
      return '$compactNetwork ****$last4';
    }
    return compactNetwork;
  }

  String _compactNetworkLabel(String network) {
    final normalized = network.trim().toLowerCase();
    if (normalized == 'mastercard') {
      return 'MC';
    }
    if (normalized == 'visa') {
      return 'Visa';
    }
    if (normalized == 'apple pay') {
      return 'Apple';
    }
    return network;
  }

  _QuickAddPaymentData _paymentForCard(CardProfile card, Expense recentExpense) {
    final network = _normalizedText(
          recentExpense.paymentNetwork ?? card.cardNetwork ?? card.customCardNetwork,
        ) ??
        'Other';
    final recentChannel = _normalizedText(recentExpense.paymentChannel);
    final channel = recentChannel == 'Online Purchase'
        ? 'Online Purchase'
        : 'POS Purchase';

    return _QuickAddPaymentData(
      method: resolvePaymentMethodHint(network, channel),
      network: network,
      channel: channel,
      cardProfileId: card.id,
    );
  }

  String? _normalizedText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  Future<void> _savePreferences([double? amount]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsLastCategoryKey, _selectedCategory);
    if (amount != null) {
      await prefs.setDouble(_prefsLastAmountKey, amount);
      final range = _amountRangeKey(amount);
      _amountCategoryMemory[range] = _selectedCategory;
      await prefs.setString(_prefsAmountMemoryKey, jsonEncode(_amountCategoryMemory));
    }
  }
  static const _QuickAddPaymentData _defaultQuickPayment = _QuickAddPaymentData(
    method: 'Cash',
    network: '',
    channel: 'Cash',
    cardProfileId: null,
  );
}

class _RepeatRestoredLine extends StatelessWidget {
  const _RepeatRestoredLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      '• $label',
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
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

class _QuickAddPaymentOption {
  const _QuickAddPaymentOption({
    required this.key,
    required this.label,
    required this.payment,
  });

  final String key;
  final String label;
  final _QuickAddPaymentData payment;
}

class _QuickAddSubmitPayload {
  const _QuickAddSubmitPayload({
    required this.title,
    required this.amount,
    required this.currencyCode,
    required this.category,
    required this.spentAt,
    required this.payment,
  });

  final String title;
  final double amount;
  final String currencyCode;
  final String category;
  final DateTime spentAt;
  final _QuickAddPaymentData payment;
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
