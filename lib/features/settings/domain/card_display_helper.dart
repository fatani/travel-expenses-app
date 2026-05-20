import 'package:flutter/material.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import 'card_profile.dart';
import 'card_profile_enums.dart';

/// Helper to format CardProfile display consistently across the app.
/// Ensures the same card format in both Arabic and English.
class CardDisplayHelper {
  static String? getBankLabel(BuildContext context, CardProfile card) {
    final l10n = AppLocalizations.of(context)!;
    return _resolveValue(
      rawValue: card.bankName,
      customValue: card.customBankName,
      explicitOtherLabel: l10n.cardBankOther,
      localizedLabel: (raw) => CardProfileEnumMapper.tryParseBank(raw)?.label(l10n),
    );
  }

  static String? getNetworkLabel(BuildContext context, CardProfile card) {
    final l10n = AppLocalizations.of(context)!;
    return _resolveValue(
      rawValue: card.cardNetwork,
      customValue: card.customCardNetwork,
      explicitOtherLabel: l10n.cardNetworkOther,
      localizedLabel: (raw) => CardProfileEnumMapper.tryParseNetwork(raw)?.label(l10n),
    );
  }

  static String? getTierLabel(BuildContext context, CardProfile card) {
    final l10n = AppLocalizations.of(context)!;
    return _resolveValue(
      rawValue: card.cardTier,
      customValue: card.customCardTier,
      explicitOtherLabel: l10n.cardTierOther,
      localizedLabel: (raw) => CardProfileEnumMapper.tryParseTier(raw)?.label(l10n),
    );
  }

  /// Generates a consistent display string for a card.
  /// Format: Bank + Network + Tier + "••••last4"
  /// Example: "SAB Mastercard World ••••4744"
  /// Fallback: Uses name for legacy cards without structured fields.
  static String getDisplayString(BuildContext context, CardProfile card) {
    // If card has structured fields, use them
    if (_hasStructuredFields(card)) {
      final parts = <String>[];

      final bankLabel = getBankLabel(context, card);
      if (bankLabel != null && bankLabel.isNotEmpty) {
        parts.add(bankLabel);
      }

      final networkLabel = getNetworkLabel(context, card);
      if (networkLabel != null && networkLabel.isNotEmpty) {
        parts.add(networkLabel);
      }

      final tierLabel = getTierLabel(context, card);
      if (tierLabel != null && tierLabel.isNotEmpty && !_shouldHideTier(card)) {
        parts.add(tierLabel);
      }

      String display = parts.isNotEmpty ? parts.join(' ') : _legacyFallback(card);

      // Add masked last4 digits at the end
      if (card.last4 != null && card.last4!.isNotEmpty && card.last4!.length == 4) {
        display += ' ••••${card.last4!}';
      }

      return display;
    }

    // Fallback for legacy cards: use stored displayName or name
    return _legacyFallback(card);
  }

  /// Check if card has any structured fields
  static bool _hasStructuredFields(CardProfile card) {
    return (card.bankName != null && card.bankName!.isNotEmpty) ||
      (card.customBankName != null && card.customBankName!.isNotEmpty) ||
        (card.cardNetwork != null && card.cardNetwork!.isNotEmpty) ||
      (card.customCardNetwork != null && card.customCardNetwork!.isNotEmpty) ||
        (card.cardTier != null && card.cardTier!.isNotEmpty) ||
      (card.customCardTier != null && card.customCardTier!.isNotEmpty) ||
        (card.last4 != null && card.last4!.isNotEmpty);
  }

  static String _legacyFallback(CardProfile card) {
    final displayName = card.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return card.name;
  }

  static bool _shouldHideTier(CardProfile card) {
    final explicitCustomTier = card.customCardTier?.trim();
    if (explicitCustomTier != null && explicitCustomTier.isNotEmpty) {
      return false;
    }

    final network = CardProfileEnumMapper.tryParseNetwork(card.cardNetwork);
    final tier = CardProfileEnumMapper.tryParseTier(card.cardTier);
    if (tier == null) {
      return false;
    }
    if (network == null) {
      return false;
    }
    return (network == CardNetwork.mada || network == CardNetwork.other) &&
        tier == CardTier.other;
  }

  static String? _resolveValue({
    required String? rawValue,
    required String? customValue,
    required String explicitOtherLabel,
    required String? Function(String rawValue) localizedLabel,
  }) {
    final trimmedCustom = customValue?.trim();
    if (trimmedCustom != null && trimmedCustom.isNotEmpty) {
      if (_isExplicitOther(trimmedCustom)) {
        return null;
      }
      return trimmedCustom;
    }

    final trimmedRaw = rawValue?.trim();
    if (trimmedRaw == null || trimmedRaw.isEmpty) {
      return null;
    }

    if (_isExplicitOther(trimmedRaw)) {
      return null;
    }

    final localized = localizedLabel(trimmedRaw);
    if (localized != null) {
      final isOther = _isExplicitOther(localized);
      if (!isOther) {
        return localized;
      }
    }

    return trimmedRaw.isEmpty ? null : trimmedRaw;
  }

  static bool _isExplicitOther(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '');
    return normalized == 'other' || normalized == 'اخرى' || normalized == 'أخرى';
  }

  /// Format with icon prefix (e.g., "💳 SAB Mastercard World ••••4744")
  static String getDisplayStringWithIcon(BuildContext context, CardProfile card) {
    return '💳 ${getDisplayString(context, card)}';
  }

  /// Get the display string while respecting text direction.
  /// In RTL (Arabic), the last4 should stay on the right side visually.
  static Widget buildDisplayText(
    BuildContext context,
    CardProfile card, {
    TextStyle? style,
    TextAlign? textAlign,
    int maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    final displayString = getDisplayString(context, card);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Text(
      displayString,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
    );
  }
}
