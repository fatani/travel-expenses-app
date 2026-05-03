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
      case 'البنكالاهلي':
      case 'الاهلي':
      case 'الأهلي':
      case 'الاهلى':
        return CardBank.snb;
      case 'alrajhi':
      case 'rajhi':
      case 'الراجحي':
        return CardBank.alRajhi;
      case 'sab':
      case 'ساب':
        return CardBank.sab;
      case 'd360':
      case 'دال360':
      case 'دال٣٦٠':
        return CardBank.d360;
      case 'barq':
      case 'برق':
        return CardBank.barq;
      case 'other':
      case 'اخرى':
      case 'أخرى':
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
      case 'فيزا':
        return CardNetwork.visa;
      case 'mastercard':
      case 'master':
      case 'ماستركارد':
        return CardNetwork.mastercard;
      case 'mada':
      case 'مدى':
      case 'مدا':
        return CardNetwork.mada;
      case 'other':
      case 'اخرى':
      case 'أخرى':
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
      case 'انفينيت':
      case 'إنفينيت':
        return CardTier.infinite;
      case 'signature':
      case 'سيجنتشر':
      case 'سيغنتشر':
        return CardTier.signature;
      case 'platinum':
      case 'بلاتينيوم':
        return CardTier.platinum;
      case 'classic':
      case 'كلاسيك':
        return CardTier.classic;
      case 'world':
      case 'وورلد':
        return CardTier.world;
      case 'worldelite':
      case 'worldelites':
      case 'وورلدايليت':
      case 'وورلدإيليت':
      case 'وورلديليت':
        return CardTier.worldElite;
      case 'other':
      case 'اخرى':
      case 'أخرى':
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