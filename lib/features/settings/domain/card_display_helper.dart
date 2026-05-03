import 'package:flutter/material.dart';
import 'package:travel_expenses/l10n/app_localizations.dart';

import 'card_profile.dart';
import 'card_profile_enums.dart';

/// Helper to format CardProfile display consistently across the app.
/// Ensures the same card format in both Arabic and English.
class CardDisplayHelper {
  /// Generates a consistent display string for a card.
  /// Format: Bank + Network + Tier + "••••last4"
  /// Example: "SAB Mastercard World ••••4744"
  /// Fallback: Uses name for legacy cards without structured fields.
  static String getDisplayString(BuildContext context, CardProfile card) {
    final l10n = AppLocalizations.of(context)!;

    // If card has structured fields, use them
    if (_hasStructuredFields(card)) {
      final parts = <String>[];

      final bank = CardProfileEnumMapper.tryParseBank(card.bankName);
      if (bank != null) {
        parts.add(bank.label(l10n));
      }

      final network = CardProfileEnumMapper.tryParseNetwork(card.cardNetwork);
      if (network != null) {
        parts.add(network.label(l10n));
      }

      final tier = CardProfileEnumMapper.tryParseTier(card.cardTier);
      if (tier != null && !_shouldHideTier(network, tier)) {
        parts.add(tier.label(l10n));
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
        (card.cardNetwork != null && card.cardNetwork!.isNotEmpty) ||
        (card.cardTier != null && card.cardTier!.isNotEmpty) ||
        (card.last4 != null && card.last4!.isNotEmpty);
  }

  static String _legacyFallback(CardProfile card) {
    final displayName = card.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }
    return card.name;
  }

  static bool _shouldHideTier(CardNetwork? network, CardTier tier) {
    if (network == null) {
      return false;
    }
    return (network == CardNetwork.mada || network == CardNetwork.other) &&
        tier == CardTier.other;
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
