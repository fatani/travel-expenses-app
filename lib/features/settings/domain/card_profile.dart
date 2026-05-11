class CardProfile {
  const CardProfile({
    required this.id,
    required this.name,
    this.bankName,
    this.customBankName,
    this.cardNetwork,
    this.customCardNetwork,
    this.cardTier,
    this.customCardTier,
    this.last4,
    this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardProfile.fromMap(Map<String, Object?> map) {
    return CardProfile(
      id: map['id']! as int,
      name: map['name']! as String,
      bankName: map['bank_name'] as String?,
      customBankName: map['custom_bank_name'] as String?,
      cardNetwork: map['card_network'] as String?,
      customCardNetwork: map['custom_card_network'] as String?,
      cardTier: map['card_tier'] as String?,
      customCardTier: map['custom_card_tier'] as String?,
      last4: map['last4'] as String?,
      displayName: map['display_name'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final int id;
  final String name;
  final String? bankName;
  final String? customBankName;
  final String? cardNetwork;
  final String? customCardNetwork;
  final String? cardTier;
  final String? customCardTier;
  final String? last4;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'bank_name': bankName,
      'custom_bank_name': customBankName,
      'card_network': cardNetwork,
      'custom_card_network': customCardNetwork,
      'card_tier': cardTier,
      'custom_card_tier': customCardTier,
      'last4': last4,
      'display_name': displayName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CardProfile copyWith({
    int? id,
    String? name,
    String? bankName,
    String? customBankName,
    String? cardNetwork,
    String? customCardNetwork,
    String? cardTier,
    String? customCardTier,
    String? last4,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      customBankName: customBankName ?? this.customBankName,
      cardNetwork: cardNetwork ?? this.cardNetwork,
      customCardNetwork: customCardNetwork ?? this.customCardNetwork,
      cardTier: cardTier ?? this.cardTier,
      customCardTier: customCardTier ?? this.customCardTier,
      last4: last4 ?? this.last4,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
