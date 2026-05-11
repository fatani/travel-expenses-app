import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_providers.dart';
import '../domain/card_profile.dart';

final cardsProvider =
    AsyncNotifierProvider<CardsNotifier, List<CardProfile>>(CardsNotifier.new);

class CardsNotifier extends AsyncNotifier<List<CardProfile>> {
  @override
  Future<List<CardProfile>> build() {
    return ref.watch(cardRepositoryProvider).getAllCards();
  }

  Future<void> addCard({
    required String name,
    String? bankName,
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
  }) async {
    await ref.read(cardRepositoryProvider).addCard(
          name: name,
          bankName: bankName,
          customBankName: customBankName,
          cardNetwork: cardNetwork,
          customCardNetwork: customCardNetwork,
          cardTier: cardTier,
          customCardTier: customCardTier,
          last4: last4,
          displayName: displayName,
        );
    ref.invalidateSelf();
  }

  Future<void> updateCard({
    required int id,
    required String name,
    String? bankName,
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
  }) async {
    await ref.read(cardRepositoryProvider).updateCard(
          id: id,
          name: name,
          bankName: bankName,
          customBankName: customBankName,
          cardNetwork: cardNetwork,
          customCardNetwork: customCardNetwork,
          cardTier: cardTier,
          customCardTier: customCardTier,
          last4: last4,
          displayName: displayName,
        );
    ref.invalidateSelf();
  }

  Future<void> deleteCard(int id) async {
    await ref.read(cardRepositoryProvider).deleteCard(id);
    ref.invalidateSelf();
  }
}

