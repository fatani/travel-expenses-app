import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/card_profile_enums.dart';
import '../domain/card_profile_exceptions.dart';
import 'cards_provider.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({
    super.key,
    this.cardId,
    this.initialCardName,
    this.initialBankName,
    this.initialCustomBankName,
    this.initialCardNetwork,
    this.initialCustomCardNetwork,
    this.initialCardTier,
    this.initialCustomCardTier,
    this.initialLast4,
    this.initialDisplayName,
  });

  final int? cardId;
  final String? initialCardName;
  final String? initialBankName;
  final String? initialCustomBankName;
  final String? initialCardNetwork;
  final String? initialCustomCardNetwork;
  final String? initialCardTier;
  final String? initialCustomCardTier;
  final String? initialLast4;
  final String? initialDisplayName;

  bool get isEditMode => cardId != null;

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _last4Controller = TextEditingController();
  final TextEditingController _customBankController = TextEditingController();
  final TextEditingController _customNetworkController = TextEditingController();
  final TextEditingController _customTierController = TextEditingController();

  CardBank? _selectedBank;
  CardNetwork? _selectedCardNetwork;
  CardTier? _selectedCardTier;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialCardName ?? '';
    _selectedBank = CardProfileEnumMapper.tryParseBank(widget.initialBankName);
    _selectedCardNetwork = CardProfileEnumMapper.tryParseNetwork(
      widget.initialCardNetwork,
    );
    final initialTier = CardProfileEnumMapper.tryParseTier(widget.initialCardTier);
    if (_selectedCardNetwork != null && initialTier != null) {
      _selectedCardTier = _selectedCardNetwork!.canonicalizeTier(initialTier);
    }
    _last4Controller.text = widget.initialLast4 ?? '';
    _customBankController.text = _initialCustomValue(
      rawValue: widget.initialBankName,
      explicitCustomValue: widget.initialCustomBankName,
    );
    _customNetworkController.text = _initialCustomValue(
      rawValue: widget.initialCardNetwork,
      explicitCustomValue: widget.initialCustomCardNetwork,
    );
    _customTierController.text = _initialCustomValue(
      rawValue: widget.initialCardTier,
      explicitCustomValue: widget.initialCustomCardTier,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    _customBankController.dispose();
    _customNetworkController.dispose();
    _customTierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isEditMode ? l10n.cardFormEditTitle : l10n.cardFormAddTitle;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final selectedNetwork = _selectedCardNetwork;
    final availableTiers = selectedNetwork?.allowedTiers ?? const <CardTier>[];
    final showTierSection = selectedNetwork != null && !selectedNetwork.hidesTierField;
    final isValid = _isFormValid();
    final saveLabel = widget.isEditMode ? l10n.cardFormSaveEdit : l10n.cardFormSaveCreate;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: l10n.cardFormCardNetworkLabel),
                          const SizedBox(height: 10),
                          _SelectorWrap<CardNetwork>(
                            options: CardNetwork.values,
                            selected: _selectedCardNetwork,
                            labelBuilder: (network) => network.label(l10n),
                            onSelected: (network) {
                              setState(() {
                                _selectedCardNetwork = network;
                                if (network.hidesTierField) {
                                  _selectedCardTier = null;
                                } else {
                                  _selectedCardTier =
                                      network.canonicalizeTier(_selectedCardTier);
                                }
                              });
                            },
                          ),
                          if (_selectedCardNetwork == CardNetwork.other) ...[
                            const SizedBox(height: 12),
                            _buildCustomField(
                              controller: _customNetworkController,
                              hintText: isArabic
                                  ? 'اكتب نوع البطاقة'
                                  : 'Enter card network',
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showTierSection) ...[
                      const SizedBox(height: 14),
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionLabel(label: l10n.cardFormCardTierLabel),
                            const SizedBox(height: 10),
                            _SelectorWrap<CardTier>(
                              options: availableTiers,
                              selected: _selectedCardTier,
                              labelBuilder: (tier) => tier.label(l10n),
                              onSelected: (tier) {
                                setState(() => _selectedCardTier = tier);
                              },
                            ),
                            if (_selectedCardTier == CardTier.other) ...[
                              const SizedBox(height: 12),
                              _buildCustomField(
                                controller: _customTierController,
                                hintText: isArabic
                                    ? 'اكتب فئة البطاقة'
                                    : 'Enter card tier',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: l10n.cardFormBankLabel),
                          const SizedBox(height: 10),
                          _SelectorWrap<CardBank>(
                            options: CardBank.values,
                            selected: _selectedBank,
                            labelBuilder: (bank) => bank.label(l10n),
                            onSelected: (bank) {
                              setState(() => _selectedBank = bank);
                            },
                          ),
                          if (_selectedBank == CardBank.other) ...[
                            const SizedBox(height: 12),
                            _buildCustomField(
                              controller: _customBankController,
                              hintText: isArabic
                                  ? 'اكتب اسم البنك'
                                  : 'Enter bank name',
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: l10n.cardFormLast4Label),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _last4Controller,
                            maxLength: 4,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              hintText: l10n.cardFormLast4Hint,
                              counterText: '',
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF7C3AED)),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: const Color(0xFFE5EAF4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.cardFormCardPreviewLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.credit_card_rounded,
                                  size: 24,
                                  color: Color(0xFF7C3AED),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _generatePreview(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Opacity(
                  opacity: isValid ? 1 : 0.55,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: isValid ? _save : null,
                      child: Ink(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.24),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            saveLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
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
    );
  }

  String _generatePreview() {
    final l10n = AppLocalizations.of(context)!;
    final bank = _selectedBank == CardBank.other
        ? _optionalCustomValue(_customBankController.text)
        : _optionalLabel(_selectedBank?.label(l10n));
    final network = _selectedCardNetwork == CardNetwork.other
        ? _optionalCustomValue(_customNetworkController.text)
        : _optionalLabel(_selectedCardNetwork?.label(l10n));
    final effectiveTier = _effectiveTier;
    final tier = effectiveTier == CardTier.other
        ? _optionalCustomValue(_customTierController.text)
        : _optionalLabel(effectiveTier?.label(l10n));
    
    final parts = <String>[];
    
    if (bank != null && !_isExplicitOther(bank)) {
      parts.add(bank);
    }
    if (network != null && !_isExplicitOther(network)) {
      parts.add(network);
    }
    if (_shouldIncludeTier(network: network, tier: tier) && 
        tier != null && 
        !_isExplicitOther(tier)) {
      parts.add(tier);
    }

    final formattedLast4 = _formatLast4Preview();
    if (formattedLast4 != null) {
      parts.add(formattedLast4);
    }

    if (parts.isEmpty) {
      return '---';
    }

    return parts.join(' • ');
  }

  bool _isFormValid() {
    if (_selectedBank == null || _selectedCardNetwork == null) {
      return false;
    }
    // Check custom text fields when "Other" is selected
    if (_selectedBank == CardBank.other &&
        _customBankController.text.trim().isEmpty) {
      return false;
    }
    if (_selectedCardNetwork == CardNetwork.other &&
        _customNetworkController.text.trim().isEmpty) {
      return false;
    }
    if (_selectedCardNetwork!.hidesTierField == false && _selectedCardTier == null) {
      return false;
    }
    if (_effectiveTier == CardTier.other && _customTierController.text.trim().isEmpty) {
      return false;
    }
    return _last4Controller.text.length == 4;
  }

  CardTier? get _effectiveTier {
    final network = _selectedCardNetwork;
    if (network == null) {
      return null;
    }
    return network.canonicalizeTier(_selectedCardTier);
  }

  Future<void> _save() async {
    if (!_isFormValid()) {
      return;
    }

    final cardName = _nameController.text.trim().isEmpty
        ? (_selectedBank == CardBank.other
            ? _customBankController.text.trim()
            : _selectedBank!.storageValue)
        : _nameController.text.trim();

    final bankName = _selectedBank == CardBank.other
        ? CardBank.other.storageValue
        : _selectedBank!.storageValue;

    final customBankName = _selectedBank == CardBank.other
        ? _customBankController.text.trim()
        : null;

    final networkName = _selectedCardNetwork == CardNetwork.other
        ? CardNetwork.other.storageValue
        : _selectedCardNetwork!.storageValue;

    final customCardNetwork = _selectedCardNetwork == CardNetwork.other
        ? _customNetworkController.text.trim()
        : null;

    final effectiveTier = _effectiveTier;
    if (effectiveTier == null || _selectedCardNetwork == null || _selectedBank == null) {
      return;
    }

    final cardTier = effectiveTier.storageValue;
    final customCardTier = effectiveTier == CardTier.other
        ? _customTierController.text.trim()
        : null;

    try {
      if (widget.isEditMode) {
        await ref.read(cardsProvider.notifier).updateCard(
              id: widget.cardId!,
              name: cardName,
              bankName: bankName,
              customBankName: customBankName,
              cardNetwork: networkName,
              customCardNetwork: customCardNetwork,
              cardTier: cardTier,
              customCardTier: customCardTier,
              last4: _last4Controller.text,
            );
      } else {
        await ref.read(cardsProvider.notifier).addCard(
              name: cardName,
              bankName: bankName,
              customBankName: customBankName,
              cardNetwork: networkName,
              customCardNetwork: customCardNetwork,
              cardTier: cardTier,
              customCardTier: customCardTier,
              last4: _last4Controller.text,
            );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on DuplicateCardProfileException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.cardFormDuplicate)),
      );
    }
  }

  Widget _buildCustomField({
    required TextEditingController controller,
    required String hintText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  String _initialCustomValue({
    required String? rawValue,
    required String? explicitCustomValue,
  }) {
    final trimmedCustom = explicitCustomValue?.trim();
    if (trimmedCustom != null && trimmedCustom.isNotEmpty) {
      return trimmedCustom;
    }

    final trimmedRaw = rawValue?.trim();
    if (trimmedRaw == null || trimmedRaw.isEmpty || _isExplicitOther(trimmedRaw)) {
      return '';
    }

    return trimmedRaw;
  }

  String? _optionalCustomValue(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String? _optionalLabel(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == '---') {
      return null;
    }
    return trimmed;
  }

  bool _shouldIncludeTier({required String? network, required String? tier}) {
    if (tier == null) {
      return false;
    }

    if (network == null) {
      return true;
    }

    final normalizedNetwork = _normalizePreviewPart(network);
    final normalizedTier = _normalizePreviewPart(tier);
    if (normalizedNetwork.isEmpty || normalizedTier.isEmpty) {
      return true;
    }

    return !normalizedNetwork.contains(normalizedTier);
  }

  String _normalizePreviewPart(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String? _formatLast4Preview() {
    final trimmed = _last4Controller.text.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final padded = trimmed.padRight(4, '•');
    return '•••• $padded';
  }

  bool _isExplicitOther(String rawValue) {
    final normalized = rawValue.trim().toLowerCase().replaceAll(' ', '');
    return normalized == 'other' || normalized == 'اخرى' || normalized == 'أخرى';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5EAF4)),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475569),
      ),
    );
  }
}

class _SelectorWrap<T> extends StatelessWidget {
  const _SelectorWrap({
    required this.options,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == selected;

        return ChoiceChip(
          selected: isSelected,
          label: Text(
            labelBuilder(option),
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
          onSelected: (_) => onSelected(option),
          selectedColor: const Color(0xFF7C3AED),
          backgroundColor: const Color(0xFFF8FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          showCheckmark: false,
        );
      }).toList(),
    );
  }
}
