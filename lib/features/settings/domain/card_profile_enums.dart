import 'package:travel_expenses/l10n/app_localizations.dart';

enum CardBank { snb, alRajhi, sab, d360, barq, other }

enum CardNetwork { visa, mastercard, mada, other }

enum CardTier { infinite, signature, platinum, classic, world, worldElite, other }

extension CardBankX on CardBank {
  String get storageValue {
    switch (this) {
      case CardBank.snb:
        return 'SNB';
      case CardBank.alRajhi:
        return 'Al Rajhi';
      case CardBank.sab:
        return 'SAB';
      case CardBank.d360:
        return 'D360';
      case CardBank.barq:
        return 'Barq';
      case CardBank.other:
        return 'Other';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case CardBank.snb:
        return l10n.cardBankSNB;
      case CardBank.alRajhi:
        return l10n.cardBankAlRajhi;
      case CardBank.sab:
        return l10n.cardBankSAB;
      case CardBank.d360:
        return l10n.cardBankD360;
      case CardBank.barq:
        return l10n.cardBankBarq;
      case CardBank.other:
        return l10n.cardBankOther;
    }
  }
}

extension CardNetworkX on CardNetwork {
  String get storageValue {
    switch (this) {
      case CardNetwork.visa:
        return 'Visa';
      case CardNetwork.mastercard:
        return 'Mastercard';
      case CardNetwork.mada:
        return 'Mada';
      case CardNetwork.other:
        return 'Other';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case CardNetwork.visa:
        return l10n.cardNetworkVisa;
      case CardNetwork.mastercard:
        return l10n.cardNetworkMastercard;
      case CardNetwork.mada:
        return l10n.cardNetworkMada;
      case CardNetwork.other:
        return l10n.cardNetworkOther;
    }
  }

  List<CardTier> get allowedTiers {
    switch (this) {
      case CardNetwork.visa:
        return const [
          CardTier.classic,
          CardTier.platinum,
          CardTier.signature,
          CardTier.infinite,
        ];
      case CardNetwork.mastercard:
        return const [
          CardTier.classic,
          CardTier.platinum,
          CardTier.world,
          CardTier.worldElite,
        ];
      case CardNetwork.mada:
        return const [CardTier.other];
      case CardNetwork.other:
        return const [CardTier.other];
    }
  }

  bool get hidesTierField => this == CardNetwork.mada;

  CardTier get defaultTier => allowedTiers.first;

  CardTier canonicalizeTier(CardTier? tier) {
    final candidate = tier ?? defaultTier;
    if (allowedTiers.contains(candidate)) {
      return candidate;
    }
    return defaultTier;
  }
}

extension CardTierX on CardTier {
  String get storageValue {
    switch (this) {
      case CardTier.infinite:
        return 'Infinite';
      case CardTier.signature:
        return 'Signature';
      case CardTier.platinum:
        return 'Platinum';
      case CardTier.classic:
        return 'Classic';
      case CardTier.world:
        return 'World';
      case CardTier.worldElite:
        return 'World Elite';
      case CardTier.other:
        return 'Other';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case CardTier.infinite:
        return l10n.cardTierInfinite;
      case CardTier.signature:
        return l10n.cardTierSignature;
      case CardTier.platinum:
        return l10n.cardTierPlatinum;
      case CardTier.classic:
        return l10n.cardTierClassic;
      case CardTier.world:
        return l10n.cardTierWorld;
      case CardTier.worldElite:
        return l10n.cardTierWorldElite;
      case CardTier.other:
        return l10n.cardTierOther;
    }
  }
}

class CardProfileEnumMapper {
  static CardBank parseBankOrOther(String? raw) {
    return tryParseBank(raw) ?? CardBank.other;
  }

  static CardNetwork parseNetworkOrOther(String? raw) {
    return tryParseNetwork(raw) ?? CardNetwork.other;
  }

  static CardTier parseTierOrOther(String? raw) {
    return tryParseTier(raw) ?? CardTier.other;
  }

  static CardBank? tryParseBank(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    switch (normalized) {
      case 'snb':
      case 'ahli':
      case 'bankalahli':
      case '\u0627\u0644\u0628\u0646\u0643\u0627\u0644\u0627\u0647\u0644\u064a':
      case '\u0627\u0644\u0627\u0647\u0644\u064a':
      case '\u0627\u0644\u0623\u0647\u0644\u064a':
      case '\u0627\u0644\u0627\u0647\u0644\u0649':
        return CardBank.snb;
      case 'alrajhi':
      case 'rajhi':
      case '\u0627\u0644\u0631\u0627\u062c\u062d\u064a':
        return CardBank.alRajhi;
      case 'sab':
      case '\u0633\u0627\u0628':
        return CardBank.sab;
      case 'd360':
      case '\u062f\u0627\u0644360':
      case '\u062f\u0627\u0644\u0663\u0666\u0660':
        return CardBank.d360;
      case 'barq':
      case '\u0628\u0631\u0642':
        return CardBank.barq;
      case 'other':
      case '\u0627\u062e\u0631\u0649':
      case '\u0623\u062e\u0631\u0649':
        return CardBank.other;
      default:
        return CardBank.other;
    }
  }

  static CardNetwork? tryParseNetwork(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    switch (normalized) {
      case 'visa':
      case '\u0641\u064a\u0632\u0627':
        return CardNetwork.visa;
      case 'mastercard':
      case 'master':
      case '\u0645\u0627\u0633\u062a\u0631\u0643\u0627\u0631\u062f':
        return CardNetwork.mastercard;
      case 'mada':
      case '\u0645\u062f\u0649':
      case '\u0645\u062f\u0627':
        return CardNetwork.mada;
      case 'other':
      case '\u0627\u062e\u0631\u0649':
      case '\u0623\u062e\u0631\u0649':
        return CardNetwork.other;
      default:
        return CardNetwork.other;
    }
  }

  static CardTier? tryParseTier(String? raw) {
    final normalized = _normalize(raw);
    if (normalized.isEmpty) return null;

    switch (normalized) {
      case 'infinite':
      case '\u0627\u0646\u0641\u064a\u0646\u064a\u062a':
      case '\u0625\u0646\u0641\u064a\u0646\u064a\u062a':
        return CardTier.infinite;
      case 'signature':
      case '\u0633\u064a\u062c\u0646\u062a\u0634\u0631':
      case '\u0633\u064a\u063a\u0646\u062a\u0634\u0631':
        return CardTier.signature;
      case 'platinum':
      case '\u0628\u0644\u0627\u062a\u064a\u0646\u064a\u0648\u0645':
        return CardTier.platinum;
      case 'classic':
      case '\u0643\u0644\u0627\u0633\u064a\u0643':
        return CardTier.classic;
      case 'world':
      case '\u0648\u0648\u0631\u0644\u062f':
        return CardTier.world;
      case 'worldelite':
      case 'worldelites':
      case '\u0648\u0648\u0631\u0644\u062f\u0627\u064a\u0644\u064a\u062a':
      case '\u0648\u0648\u0631\u0644\u062f\u0625\u064a\u0644\u064a\u062a':
      case '\u0648\u0648\u0631\u0644\u062f\u064a\u0644\u064a\u062a':
        return CardTier.worldElite;
      case 'other':
      case '\u0627\u062e\u0631\u0649':
      case '\u0623\u062e\u0631\u0649':
        return CardTier.other;
      default:
        return CardTier.other;
    }
  }

  static String _normalize(String? value) {
    if (value == null) return '';
    return value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  }
}
