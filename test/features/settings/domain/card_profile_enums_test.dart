import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses/features/settings/domain/card_profile_enums.dart';

void main() {
  group('CardNetwork tier support', () {
    test('Mada supports card tier selector', () {
      expect(CardNetwork.mada.supportsCardTier, isTrue);
    });

    test('Visa and MasterCard support card tier selector', () {
      expect(CardNetwork.visa.supportsCardTier, isTrue);
      expect(CardNetwork.mastercard.supportsCardTier, isTrue);
    });

    test('Mada allows standard tier options', () {
      expect(
        CardNetwork.mada.allowedTiers,
        containsAll(<CardTier>[
          CardTier.classic,
          CardTier.platinum,
          CardTier.signature,
          CardTier.infinite,
        ]),
      );
    });

    test('Mada network parses from storage and Arabic labels', () {
      expect(CardProfileEnumMapper.tryParseNetwork('Mada'), CardNetwork.mada);
      expect(CardProfileEnumMapper.tryParseNetwork('mada'), CardNetwork.mada);
      expect(CardProfileEnumMapper.tryParseNetwork('مدى'), CardNetwork.mada);
    });
  });
}
