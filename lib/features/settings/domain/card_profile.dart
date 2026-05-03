class CardProfile {
  const CardProfile({
    required this.id,
    required this.name,
    this.bankName,
    this.cardNetwork,
    this.cardTier,
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
      cardNetwork: map['card_network'] as String?,
      cardTier: map['card_tier'] as String?,
      last4: map['last4'] as String?,
      displayName: map['display_name'] as String?,
      createdAt: DateTime.parse(map['created_at']! as String),
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final int id;
  final String name;
  final String? bankName;
  final String? cardNetwork;
  final String? cardTier;
  final String? last4;
  final String? displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'bank_name': bankName,
      'card_network': cardNetwork,
      'card_tier': cardTier,
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
    String? cardNetwork,
    String? cardTier,
    String? last4,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      cardNetwork: cardNetwork ?? this.cardNetwork,
      cardTier: cardTier ?? this.cardTier,
      last4: last4 ?? this.last4,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
