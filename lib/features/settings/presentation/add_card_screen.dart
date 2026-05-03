import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/card_display_helper.dart';
import '../domain/card_profile.dart';
import '../domain/card_profile_enums.dart';
import '../domain/card_profile_exceptions.dart';
import 'cards_provider.dart';

class AddCardScreen extends ConsumerStatefulWidget {
  const AddCardScreen({
    super.key,
    this.cardId,
    this.initialCardName,
    this.initialBankName,
    this.initialCardNetwork,
    this.initialCardTier,
    this.initialLast4,
    this.initialDisplayName,
  });

  final int? cardId;
  final String? initialCardName;
  final String? initialBankName;
  final String? initialCardNetwork;
  final String? initialCardTier;
  final String? initialLast4;
  final String? initialDisplayName;

  bool get isEditMode => cardId != null;

  @override
  ConsumerState<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends ConsumerState<AddCardScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _last4Controller = TextEditingController();

  CardBank _selectedBank = CardBank.other;
  CardNetwork _selectedCardNetwork = CardNetwork.other;
  CardTier _selectedCardTier = CardTier.other;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialCardName ?? '';
    _selectedBank = CardProfileEnumMapper.parseBankOrOther(widget.initialBankName);
    _selectedCardNetwork = CardProfileEnumMapper.parseNetworkOrOther(
      widget.initialCardNetwork,
    );
    final initialTier = CardProfileEnumMapper.parseTierOrOther(
      widget.initialCardTier,
    );
    _selectedCardTier = _selectedCardNetwork.canonicalizeTier(initialTier);
    _last4Controller.text = widget.initialLast4 ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _last4Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.isEditMode ? l10n.cardFormEditTitle : l10n.cardFormAddTitle;
    final availableTiers = _selectedCardNetwork.allowedTiers;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<CardBank>(
                initialValue: _selectedBank,
                decoration: InputDecoration(
                  labelText: _requiredLabel(l10n.cardFormBankLabel),
                ),
                items: CardBank.values
                    .map(
                      (bank) => DropdownMenuItem<CardBank>(
                        value: bank,
                        child: Text(bank.label(l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedBank = value);
                },
                validator: _validateRequired,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<CardNetwork>(
                initialValue: _selectedCardNetwork,
                decoration: InputDecoration(
                  labelText: _requiredLabel(l10n.cardFormCardNetworkLabel),
                ),
                items: CardNetwork.values
                    .map(
                      (network) => DropdownMenuItem<CardNetwork>(
                        value: network,
                        child: Text(network.label(l10n)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedCardNetwork = value;
                    _selectedCardTier = value.canonicalizeTier(_selectedCardTier);
                  });
                },
                validator: _validateRequired,
              ),
              if (!_selectedCardNetwork.hidesTierField) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<CardTier>(
                  key: ValueKey(_selectedCardNetwork),
                  initialValue: _selectedCardNetwork.canonicalizeTier(_selectedCardTier),
                  decoration: InputDecoration(labelText: l10n.cardFormCardTierLabel),
                  items: availableTiers
                      .map(
                        (tier) => DropdownMenuItem<CardTier>(
                          value: tier,
                          child: Text(tier.label(l10n)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCardTier = value);
                  },
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _last4Controller,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.cardFormLast4Label,
                  hintText: l10n.cardFormLast4Hint,
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cardFormCardPreviewLabel,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _generatePreview(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isFormValid() ? _save : null,
                child: Text(
                  widget.isEditMode ? l10n.cardFormSaveEdit : l10n.cardFormSaveCreate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _generatePreview() {
    final tempCard = CardProfile(
      id: 0,
      name: _nameController.text.isNotEmpty ? _nameController.text : 'Card',
      bankName: _selectedBank.storageValue,
      cardNetwork: _selectedCardNetwork.storageValue,
      cardTier: _effectiveTier.storageValue,
      last4: _last4Controller.text.isNotEmpty ? _last4Controller.text : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return CardDisplayHelper.getDisplayString(context, tempCard);
  }

  bool _isFormValid() {
    return _last4Controller.text.length == 4;
  }

  CardTier get _effectiveTier => _selectedCardNetwork.canonicalizeTier(
    _selectedCardTier,
  );

  String? _validateRequired<T>(T? value) {
    if (value == null) {
      return AppLocalizations.of(context)!.commonRequiredField;
    }
    return null;
  }

  String _requiredLabel(String label) => '$label *';

  Future<void> _save() async {
    if (!_isFormValid()) {
      return;
    }

    final cardName = _nameController.text.trim().isEmpty
        ? _selectedBank.storageValue
        : _nameController.text.trim();

    try {
      if (widget.isEditMode) {
        await ref.read(cardsProvider.notifier).updateCard(
              id: widget.cardId!,
              name: cardName,
              bankName: _selectedBank.storageValue,
              cardNetwork: _selectedCardNetwork.storageValue,
              cardTier: _effectiveTier.storageValue,
              last4: _last4Controller.text,
            );
      } else {
        await ref.read(cardsProvider.notifier).addCard(
              name: cardName,
              bankName: _selectedBank.storageValue,
              cardNetwork: _selectedCardNetwork.storageValue,
              cardTier: _effectiveTier.storageValue,
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
}
